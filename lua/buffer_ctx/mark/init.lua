---@module 'buffer_ctx.mark'
---@brief :Mark command tree — toggle per-line marks and yank them to clipboard.
---@description
--- :Mark toggle   Toggle the mark on the current line (sign or extmark indicator)
--- :Mark yank     Yank all marked lines (in buffer order) to the system clipboard
---
--- Built via lib.nvim.usercmd.composer. Compat commands are registered
--- directly (untouched by composer, preserving their exact standalone
--- surface):
---   :MarkLineToggle   →  :Mark toggle
---   :MarkLinesYank    →  :Mark yank

---@see buffer_ctx.util.map for the lib.nvim keymap soft bridge
---@see buffer_ctx.util.clip for the clipboard sink M.yank writes through

local composer = require("lib.nvim.usercmd.composer")
local usercmd = require("lib.nvim.usercmd")
local autocmd = require("lib.nvim.autocmd")
local notify = require("buffer_ctx.util.notify")
local map = require("buffer_ctx.util.map")
local clip = require("buffer_ctx.util.clip")

local M = {}

-- Per-buffer mark state: buf → { [extmark_id] = true }
--
-- The extmark ID is the identity, NOT the line number. Neovim moves an
-- extmark automatically when lines are inserted or deleted above it; it
-- cannot move a plain integer table key. Keying by line number meant the
-- visual indicator and the underlying data silently diverged after any edit
-- above a mark, so `:Mark yank` copied whatever had since moved into that
-- line slot. See docs/ROADMAP/anchor-stable-marks.md.
---@type table<number, table<number, boolean>>
local marked = {}

local SIGN_NAME = "BufferCtxMarkSign"
local VIRT_NS = vim.api.nvim_create_namespace("BufferCtxMarkVirt")
local sign_defined = false

---@type { text: string, hl: string }
local sign_opts = { text = "●", hl = "ErrorMsg" }

local function ensure_sign()
  if sign_defined then
    return
  end
  vim.fn.sign_define(SIGN_NAME, { text = sign_opts.text, texthl = sign_opts.hl })
  sign_defined = true
end

local function use_signcolumn()
  return vim.api.nvim_get_option_value("signcolumn", { win = 0 }) ~= "no"
end

-- 0.10 brought two extmark features this module wants, so they share a gate:
--
--   sign_text/sign_hl_group — lets the sign-column rendering ride on the very
--     same extmark that carries the identity, so there is exactly one
--     tracking mechanism. On 0.9 (still the documented floor) a real sign is
--     placed alongside, keyed by the extmark ID so the two stay addressable
--     as one unit.
--
--   invalidate/undo_restore — without it an extmark whose line is deleted
--     collapses onto the following line rather than disappearing, so deleting
--     a marked line would silently transfer the mark to its neighbour. With
--     `invalidate = true, undo_restore = false` the extmark is deleted
--     outright, which is what "the marked line is gone" should mean.
--     On 0.9 the mark still slides to the neighbouring line — much better
--     than the old raw-line-number behaviour, but not exact.
local function extmark_v10()
  return vim.fn.has("nvim-0.10") == 1
end

---Place the indicator for a new mark and return its extmark ID.
---@param bufnr number
---@param lnum  number  1-based
---@return integer extmark_id
local function place_mark(bufnr, lnum)
  local modern = extmark_v10()
  local opts
  if use_signcolumn() and modern then
    opts = { sign_text = sign_opts.text, sign_hl_group = sign_opts.hl }
  else
    opts = {
      virt_text = { { sign_opts.text, sign_opts.hl } },
      virt_text_pos = "overlay",
    }
  end

  if modern then
    -- Delete the extmark outright when its line is deleted, rather than
    -- letting it collapse onto the next line and silently re-mark it.
    opts.invalidate = true
    opts.undo_restore = false
  end

  local id = vim.api.nvim_buf_set_extmark(bufnr, VIRT_NS, lnum - 1, 0, opts)

  if use_signcolumn() and not modern then
    ensure_sign()
    vim.fn.sign_place(id, SIGN_NAME, SIGN_NAME, bufnr, { lnum = lnum })
  end

  return id
end

---Remove a mark's indicator(s). Idempotent, and deliberately clears both
---renderings: `signcolumn` can be toggled between placing and removing a
---mark, so the branch that created it is not necessarily the branch running
---now.
---@param bufnr number
---@param id    integer  extmark ID
local function unplace_mark(bufnr, id)
  pcall(vim.api.nvim_buf_del_extmark, bufnr, VIRT_NS, id)
  pcall(vim.fn.sign_unplace, SIGN_NAME, { buffer = bufnr, id = id })
end

---Resolve an extmark ID to its current 1-based line, or nil if it is gone
---(the line it anchored to was deleted).
---@param bufnr number
---@param id    integer
---@return integer|nil lnum
local function resolve_line(bufnr, id)
  local pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, VIRT_NS, id, {})
  if not pos or not pos[1] then
    return nil
  end
  return pos[1] + 1
end

---Find the mark currently anchored to `lnum`, if any.
---@param bufnr number
---@param lnum  number  1-based
---@return integer|nil extmark_id
local function mark_at(bufnr, lnum)
  local ids = marked[bufnr]
  if not ids then
    return nil
  end
  for id in pairs(ids) do
    if resolve_line(bufnr, id) == lnum then
      return id
    end
  end
  return nil
end

-- ── Core operations ───────────────────────────────────────────────────────────

---Toggle the mark on line `lnum` in `bufnr`.
---@param lnum  number
---@param bufnr number|nil
function M.toggle(lnum, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  marked[bufnr] = marked[bufnr] or {}

  -- Which mark (if any) sits on this line is resolved through the extmarks
  -- themselves, so a mark that has drifted with the text is still recognised
  -- as being on its current line.
  local existing = mark_at(bufnr, lnum)
  if existing then
    marked[bufnr][existing] = nil
    unplace_mark(bufnr, existing)
  else
    marked[bufnr][place_mark(bufnr, lnum)] = true
  end
end

---Yank all marked lines in `bufnr` (sorted by line number) to the system clipboard.
---@param bufnr number|nil
function M.yank(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    notify.warn("Invalid buffer")
    return
  end
  local ids = marked[bufnr]
  if not ids then
    notify.warn("No marked lines in this buffer")
    return
  end

  -- Sort by the *resolved* current line, not by extmark ID: IDs are handed
  -- out in creation order, which stops matching buffer order as soon as marks
  -- are toggled off and on again, or lines are reordered.
  local sorted = {}
  for id in pairs(ids) do
    local lnum = resolve_line(bufnr, id)
    if lnum then
      sorted[#sorted + 1] = lnum
    else
      -- The marked line itself was deleted; drop the now-dangling mark.
      ids[id] = nil
    end
  end
  table.sort(sorted)

  local text = {}
  for _, lnum in ipairs(sorted) do
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
    if line then
      text[#text + 1] = line
    end
  end

  if #text > 0 then
    -- Route through the shared clip sink rather than writing "+" directly:
    -- that is what gives mark.yank the lib.nvim fallback chain, the unnamed
    -- register write, and the missing-provider guard.
    clip.copy(table.concat(text, "\n"), { silent = true })
    notify.info("Copied " .. #text .. " marked line(s) to clipboard")
  else
    notify.warn("No marked lines to copy")
  end
end

-- ── Setup ─────────────────────────────────────────────────────────────────────

---@param opts BufferCtx.MarkConfig
function M.setup(opts)
  local cmd_name = (type(opts) == "table" and type(opts.command) == "string") and opts.command
    or "Mark"

  if type(opts) == "table" and type(opts.sign) == "table" then
    sign_opts.text = opts.sign.text or sign_opts.text
    sign_opts.hl = opts.sign.hl or sign_opts.hl
  end

  composer.verb(cmd_name, {
    desc = "Line-mark operations: toggle / yank",
    routes = {
      {
        path = { "toggle" },
        desc = "Toggle the mark on the current line",
        run = function()
          M.toggle(vim.api.nvim_win_get_cursor(0)[1])
        end,
      },
      {
        path = { "yank" },
        desc = "Yank all marked lines to the system clipboard",
        run = function()
          M.yank()
        end,
      },
    },
  })

  -- Compat commands (preserve wkdoptions.ui.line_marker API)
  usercmd.create("MarkLineToggle", function()
    M.toggle(vim.api.nvim_win_get_cursor(0)[1])
  end, { desc = "[buffer-ctx compat] Toggle mark on current line" })

  usercmd.create("MarkLinesYank", function()
    M.yank()
  end, { desc = "[buffer-ctx compat] Yank all marked lines" })

  -- Clear mark state for buffers that get deleted/wiped out, so `marked`
  -- doesn't grow unbounded over a long session.
  autocmd.create({ "BufDelete", "BufWipeout" }, function(args)
    marked[args.buf] = nil
  end, {
    group = "BufferCtxMarkCleanup",
    desc = "[buffer-ctx] clear mark state for deleted buffer",
  })

  -- Optional keymaps
  local km = type(opts) == "table" and opts.keymaps or nil
  if km and km ~= false then
    if type(km.toggle) == "string" then
      map.set("n", km.toggle, function()
        M.toggle(vim.api.nvim_win_get_cursor(0)[1])
      end, "[buffer-ctx] Mark: toggle line")
    end
    if type(km.yank) == "string" then
      map.set("n", km.yank, function()
        M.yank()
      end, "[buffer-ctx] Mark: yank marked lines")
    end
  end
end

return M
