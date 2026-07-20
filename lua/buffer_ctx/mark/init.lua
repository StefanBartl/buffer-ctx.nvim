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

-- Per-buffer mark state: buf → { [lnum] = true }
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
  ensure_sign()

  if marked[bufnr][lnum] then
    marked[bufnr][lnum] = nil
    if use_signcolumn() then
      vim.fn.sign_unplace(SIGN_NAME, { buffer = bufnr, id = lnum })
    else
      vim.api.nvim_buf_clear_namespace(bufnr, VIRT_NS, lnum - 1, lnum)
    end
  else
    marked[bufnr][lnum] = true
    if use_signcolumn() then
      vim.fn.sign_place(lnum, SIGN_NAME, SIGN_NAME, bufnr, { lnum = lnum })
    else
      vim.api.nvim_buf_set_extmark(bufnr, VIRT_NS, lnum - 1, 0, {
        virt_text = { { sign_opts.text, sign_opts.hl } },
        virt_text_pos = "overlay",
      })
    end
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
  local lines = marked[bufnr]
  if not lines then
    notify.warn("No marked lines in this buffer")
    return
  end

  local sorted = {}
  for lnum in pairs(lines) do
    sorted[#sorted + 1] = lnum
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
      { path = { "toggle" }, desc = "Toggle the mark on the current line",
        run = function() M.toggle(vim.api.nvim_win_get_cursor(0)[1]) end },
      { path = { "yank" }, desc = "Yank all marked lines to the system clipboard",
        run = function() M.yank() end },
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
