---@module 'buffer_ctx.mark'
--- :Mark command tree — toggle per-line marks and yank them to clipboard.
--- :Mark toggle   Toggle the mark on the current line (sign or extmark indicator)
--- :Mark yank     Yank all marked lines (in buffer order) to the system clipboard
---
--- Built via lib.nvim.bindings.usercmd.composer. Compat commands are registered
--- directly (untouched by composer, preserving their exact standalone
--- surface):
---   :MarkLineToggle   →  :Mark toggle
---   :MarkLinesYank    →  :Mark yank

---@see buffer_ctx.util.map for the lib.nvim keymap soft bridge
---@see buffer_ctx.util.clip for the clipboard sink M.yank writes through

local composer = require("lib.nvim.bindings.usercmd.composer")
local usercmd = require("lib.nvim.bindings.usercmd")
local autocmd = require("lib.nvim.bindings.autocmd")
local notify = require("buffer_ctx.util.notify")
local map = require("buffer_ctx.util.map")
local clip = require("buffer_ctx.util.clip")

local M = {}

-- Per-buffer mark state: buf → { [extmark_id] = category_name }
--
-- The value is the category the mark belongs to (see `categories` below).
-- It was a plain `true` while there was only one appearance to give a mark;
-- storing the name is what lets `:Mark yank`/`clear` filter by category
-- without a second table to keep in sync.
--
-- The extmark ID is the identity, NOT the line number. Neovim moves an
-- extmark automatically when lines are inserted or deleted above it; it
-- cannot move a plain integer table key. Keying by line number meant the
-- visual indicator and the underlying data silently diverged after any edit
-- above a mark, so `:Mark yank` copied whatever had since moved into that
-- line slot. See docs/ROADMAP/anchor-stable-marks.md.
---@type table<number, table<number, string>>
local marked = {}

---@internal
---Extmark IDs currently marked in `bufnr` (mapped to their category), or nil
---if none.
---@param bufnr number
---@return table<number, string>|nil
local function get_marks(bufnr)
  return marked[bufnr]
end

---@internal
---Record `id` as marked in `bufnr`, creating the per-buffer set if needed.
---@param bufnr number
---@param id integer
---@param category string
local function add_mark(bufnr, id, category)
  marked[bufnr] = marked[bufnr] or {}
  marked[bufnr][id] = category
end

---@internal
---Forget `id` in `bufnr` (no-op if `bufnr` has no marks at all).
---@param bufnr number
---@param id integer
local function remove_mark(bufnr, id)
  if marked[bufnr] then
    marked[bufnr][id] = nil
  end
end

---@internal
---Drop all mark state for `bufnr` (used on BufDelete/BufWipeout).
---@param bufnr number
local function clear_marks(bufnr)
  marked[bufnr] = nil
end

local SIGN_NAME = "BufferCtxMarkSign"
local VIRT_NS = vim.api.nvim_create_namespace("BufferCtxMarkVirt")
---Categories a mark can belong to, each with its own appearance.
---
--- There used to be exactly one, `sign_opts`, so every mark in a buffer
--- looked identical -- fine for "these lines", useless for "these lines for
--- *this* reason and those for another". `mark.categories` in the config
--- replaces or extends this table; `mark.sign` still sets `default`'s
--- appearance, so an existing config keeps working untouched.
---@type table<string, { text: string, hl: string }>
local categories = {
  default = { text = "●", hl = "ErrorMsg" },
}

---Order categories were declared in, for `:Mark toggle <Tab>` and for the
---cycling in `M.toggle` -- `pairs` order would make both nondeterministic.
---@type string[]
local category_order = { "default" }

---The category used when none is named.
local DEFAULT_CATEGORY = "default"

---@internal
---@param name string|nil
---@return { text: string, hl: string }
local function category_opts(name)
  return categories[name or DEFAULT_CATEGORY] or categories[DEFAULT_CATEGORY]
end

---Signs are defined per category, once each. Only used on the 0.9 path,
---where a real sign is placed alongside the extmark.
---@type table<string, boolean>
local sign_defined = {}

---@internal
---@param category string
---@return string sign_name
local function ensure_sign(category)
  local name = SIGN_NAME .. "_" .. category
  if sign_defined[name] then
    return name
  end
  local opts = category_opts(category)
  vim.fn.sign_define(name, { text = opts.text, texthl = opts.hl })
  sign_defined[name] = true
  return name
end

---@internal
---@return boolean
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
---@internal
---@return boolean
local function extmark_v10()
  return vim.fn.has("nvim-0.10") == 1
end

---@internal
---Place the indicator for a new mark and return its extmark ID.
---@param bufnr number
---@param lnum  number  1-based
---@param category string|nil  defaults to `default`
---@return integer extmark_id
local function place_mark(bufnr, lnum, category)
  local modern = extmark_v10()
  local look = category_opts(category)
  local opts
  if use_signcolumn() and modern then
    opts = { sign_text = look.text, sign_hl_group = look.hl }
  else
    opts = {
      virt_text = { { look.text, look.hl } },
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
    local sign_name = ensure_sign(category or DEFAULT_CATEGORY)
    vim.fn.sign_place(id, SIGN_NAME, sign_name, bufnr, { lnum = lnum })
  end

  return id
end

---@internal
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

---@internal
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

---@internal
---Find the mark currently anchored to `lnum`, if any.
---@param bufnr number
---@param lnum  number  1-based
---@return integer|nil extmark_id
local function mark_at(bufnr, lnum)
  local ids = get_marks(bufnr)
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
---
--- With a `category`, a line already marked in a *different* category is
--- re-marked rather than unmarked: asking for "red here" on a green line
--- means you want red, not nothing.
---@param lnum  number
---@param bufnr number|nil
---@param category string|nil
function M.toggle(lnum, bufnr, category)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  -- Which mark (if any) sits on this line is resolved through the extmarks
  -- themselves, so a mark that has drifted with the text is still recognised
  -- as being on its current line.
  local existing = mark_at(bufnr, lnum)
  if existing then
    local same = (marked[bufnr] and marked[bufnr][existing]) == (category or DEFAULT_CATEGORY)
    remove_mark(bufnr, existing)
    unplace_mark(bufnr, existing)
    if same then
      return
    end
  end
  add_mark(bufnr, place_mark(bufnr, lnum, category), category or DEFAULT_CATEGORY)
end

---Toggle the marks on every line in `line1..line2`.
---
--- Deliberately not a per-line toggle. Over a five-line selection with two
--- lines already marked, toggling each one leaves a checkerboard -- which
--- looks broken rather than useful. So: if any line in the range is unmarked
--- (or marked in another category), mark the whole range; only when every
--- line already carries this category does it unmark the whole range.
---@param line1 number  1-based, inclusive
---@param line2 number  1-based, inclusive
---@param bufnr number|nil
---@param category string|nil
---@return integer changed  # lines whose state actually changed
function M.toggle_range(line1, line2, bufnr, category)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return 0
  end
  if line1 > line2 then
    line1, line2 = line2, line1
  end

  local want = category or DEFAULT_CATEGORY
  local ids = get_marks(bufnr)

  local all_marked = true
  for lnum = line1, line2 do
    local id = mark_at(bufnr, lnum)
    if not id or (ids and ids[id]) ~= want then
      all_marked = false
      break
    end
  end

  local changed = 0
  for lnum = line1, line2 do
    local id = mark_at(bufnr, lnum)
    if all_marked then
      if id then
        remove_mark(bufnr, id)
        unplace_mark(bufnr, id)
        changed = changed + 1
      end
    elseif not id or (get_marks(bufnr) or {})[id] ~= want then
      if id then
        remove_mark(bufnr, id)
        unplace_mark(bufnr, id)
      end
      add_mark(bufnr, place_mark(bufnr, lnum, want), want)
      changed = changed + 1
    end
  end

  return changed
end

---Remove every mark in `bufnr`, or only those in `category`.
---
--- The only way to unmark before this was to toggle each line individually,
--- which for a buffer full of marks means finding them first.
---@param bufnr number|nil
---@param category string|nil  # nil clears all categories
---@return integer removed
function M.clear(bufnr, category)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    notify.warn("Invalid buffer")
    return 0
  end

  local ids = get_marks(bufnr)
  if not ids then
    return 0
  end

  local removed = 0
  for id, cat in pairs(vim.deepcopy(ids)) do
    if category == nil or cat == category then
      remove_mark(bufnr, id)
      unplace_mark(bufnr, id)
      removed = removed + 1
    end
  end

  if next(marked[bufnr] or {}) == nil then
    clear_marks(bufnr)
  end

  return removed
end

---Yank all marked lines in `bufnr` (sorted by line number) to the system clipboard.
---@param bufnr number|nil
---@param category string|nil  # nil yanks every category
function M.yank(bufnr, category)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    notify.warn("Invalid buffer")
    return
  end
  local ids = get_marks(bufnr)
  if not ids then
    notify.warn("No marked lines in this buffer")
    return
  end

  -- Sort by the *resolved* current line, not by extmark ID: IDs are handed
  -- out in creation order, which stops matching buffer order as soon as marks
  -- are toggled off and on again, or lines are reordered.
  local sorted = {}
  for id, cat in pairs(ids) do
    local lnum = resolve_line(bufnr, id)
    if not lnum then
      -- The marked line itself was deleted; drop the now-dangling mark.
      remove_mark(bufnr, id)
    elseif category == nil or cat == category then
      sorted[#sorted + 1] = lnum
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
    -- register write, and the missing-provider guard. clip.copy is a pure
    -- sink now (returns status only), so this caller owns the notification.
    local copy_ok, copy_err = clip.copy(table.concat(text, "\n"))
    if copy_ok then
      notify.info("Copied " .. #text .. " marked line(s) to clipboard")
    else
      notify.warn(copy_err or "copy failed")
    end
  else
    notify.warn("No marked lines to copy")
  end
end

-- ── Setup ─────────────────────────────────────────────────────────────────────

---@param opts BufferCtx.MarkConfig
function M.setup(opts)
  local cmd_name = (type(opts) == "table" and type(opts.command) == "string") and opts.command
    or "Mark"

  -- `mark.sign` still configures the `default` category, so a config written
  -- before categories existed keeps working with no change.
  if type(opts) == "table" and type(opts.sign) == "table" then
    categories.default.text = opts.sign.text or categories.default.text
    categories.default.hl = opts.sign.hl or categories.default.hl
  end

  if type(opts) == "table" and type(opts.categories) == "table" then
    for _, cat in ipairs(opts.categories) do
      if type(cat) == "table" and type(cat.name) == "string" and cat.name ~= "" then
        local known = categories[cat.name] ~= nil
        categories[cat.name] = {
          text = cat.text or categories.default.text,
          hl = cat.hl or categories.default.hl,
        }
        if not known then
          category_order[#category_order + 1] = cat.name
        end
      else
        notify.warn("mark.categories: each entry needs a non-empty `name`")
      end
    end
  end

  composer.register_type("MARK_CATEGORY", {
    validate = function(raw)
      if categories[raw] then
        return true, raw, nil
      end
      return false,
        nil,
        ("unknown mark category %q — configured: %s"):format(
          raw,
          table.concat(category_order, ", ")
        )
    end,
    -- Read live rather than captured: `setup()` may run again during config
    -- development, and a frozen list would keep offering the old categories.
    complete = function(arg_lead)
      local out = {}
      for _, name in ipairs(category_order) do
        if name:find(arg_lead or "", 1, true) == 1 then
          out[#out + 1] = name
        end
      end
      return out
    end,
  })

  composer.verb(cmd_name, {
    desc = "Line-mark operations: toggle / yank",
    routes = {
      {
        path = { "toggle" },
        args = { { name = "category", type = "MARK_CATEGORY", optional = true } },
        range = true,
        desc = "Toggle the mark on the current line, or over a range",
        run = function(ctx)
          -- A real range (`:'<,'>Mark toggle`) covers the selection; without
          -- one, `line1`/`line2` both default to the cursor line, so the
          -- single-line case falls out of the same call.
          if ctx.range.range and ctx.range.range > 0 then
            local n = M.toggle_range(ctx.range.line1, ctx.range.line2, nil, ctx.args.category)
            notify.info(("Toggled %d line(s)"):format(n))
          else
            M.toggle(vim.api.nvim_win_get_cursor(0)[1], nil, ctx.args.category)
          end
        end,
      },
      {
        path = { "clear" },
        args = { { name = "category", type = "MARK_CATEGORY", optional = true } },
        desc = "Remove every mark in this buffer (optionally only one category)",
        run = function(ctx)
          local n = M.clear(nil, ctx.args.category)
          if n > 0 then
            notify.info(("Cleared %d mark(s)"):format(n))
          else
            notify.warn("No marks to clear")
          end
        end,
      },
      {
        path = { "yank" },
        args = { { name = "category", type = "MARK_CATEGORY", optional = true } },
        desc = "Yank all marked lines to the system clipboard",
        run = function(ctx)
          M.yank(nil, ctx.args.category)
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
    clear_marks(args.buf)
  end, {
    group = "BufferCtxMarkCleanup",
    desc = "[buffer-ctx] clear mark state for deleted buffer",
  })

  -- Optional keymaps
  local km = type(opts) == "table" and opts.keymaps or nil
  if km and km ~= false then
    if type(km.toggle) == "string" then
      map.set("n", km.toggle, function()
        -- A count marks that many lines from the cursor down, clamped to the
        -- end of the buffer. Without one this is the single-line toggle it
        -- has always been -- `count1` is 1 then, and toggle_range over a
        -- one-line range is the same operation.
        local n = require("lib.nvim.count").get()
        local line = vim.api.nvim_win_get_cursor(0)[1]
        if n <= 1 then
          M.toggle(line)
          return
        end
        local last = math.min(line + n - 1, vim.api.nvim_buf_line_count(0))
        local changed = M.toggle_range(line, last)
        notify.info(("Toggled %d line(s)"):format(changed))
      end, "[buffer-ctx] Mark: toggle line (or N with a count)")
    end

    if type(km.clear) == "string" then
      map.set("n", km.clear, function()
        local removed = M.clear()
        if removed > 0 then
          notify.info(("Cleared %d mark(s)"):format(removed))
        else
          notify.warn("No marks to clear")
        end
      end, "[buffer-ctx] Mark: clear all marks")
    end
    if type(km.yank) == "string" then
      map.set("n", km.yank, function()
        M.yank()
      end, "[buffer-ctx] Mark: yank marked lines")
    end
  end
end

return M
