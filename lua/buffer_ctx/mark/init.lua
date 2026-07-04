---@module 'buffer_ctx.mark'
---@brief :Mark command tree — toggle per-line marks and yank them to clipboard.
---@description
--- :Mark toggle   Toggle the mark on the current line (sign or extmark indicator)
--- :Mark yank     Yank all marked lines (in buffer order) to the system clipboard
---
--- Compat commands registered automatically:
---   :MarkLineToggle   →  :Mark toggle
---   :MarkLinesYank    →  :Mark yank

local notify = require("buffer_ctx.util.notify")

local M = {}

-- Per-buffer mark state: buf → { [lnum] = true }
---@type table<number, table<number, boolean>>
local marked = {}

local SIGN_NAME    = "BufferCtxMarkSign"
local VIRT_NS      = vim.api.nvim_create_namespace("BufferCtxMarkVirt")
local sign_defined = false

---@type { text: string, hl: string }
local sign_opts = { text = "●", hl = "ErrorMsg" }

local function ensure_sign()
  if sign_defined then return end
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
        virt_text     = { { sign_opts.text, sign_opts.hl } },
        virt_text_pos = "overlay",
      })
    end
  end
end

---Yank all marked lines in `bufnr` (sorted by line number) to the system clipboard.
---@param bufnr number|nil
function M.yank(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = marked[bufnr]
  if not lines then
    notify.warn("No marked lines in this buffer")
    return
  end

  local sorted = {}
  for lnum in pairs(lines) do sorted[#sorted + 1] = lnum end
  table.sort(sorted)

  local text = {}
  for _, lnum in ipairs(sorted) do
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
    if line then text[#text + 1] = line end
  end

  if #text > 0 then
    vim.fn.setreg("+", table.concat(text, "\n"))
    notify.info("Copied " .. #text .. " marked line(s) to clipboard")
  else
    notify.warn("No marked lines to copy")
  end
end

-- ── Subcommand registry ───────────────────────────────────────────────────────

local SUBCOMMANDS = { "toggle", "yank" }

local function dispatch(subcmd)
  if subcmd == "toggle" then
    M.toggle(vim.api.nvim_win_get_cursor(0)[1])
  elseif subcmd == "yank" then
    M.yank()
  else
    notify.warn("Unknown subcommand '" .. tostring(subcmd) .. "'. Valid: toggle, yank")
  end
end

local function complete(arglead)
  if arglead == "" then return SUBCOMMANDS end
  local lead = arglead:lower()
  local out  = {}
  for _, s in ipairs(SUBCOMMANDS) do
    if s:sub(1, #lead) == lead then out[#out + 1] = s end
  end
  return out
end

-- ── Setup ─────────────────────────────────────────────────────────────────────

---@param opts BufferCtx.MarkConfig
function M.setup(opts)
  local cmd_name = (type(opts) == "table" and type(opts.command) == "string")
    and opts.command or "Mark"

  if type(opts) == "table" and type(opts.sign) == "table" then
    sign_opts.text = opts.sign.text or sign_opts.text
    sign_opts.hl   = opts.sign.hl or sign_opts.hl
  end

  vim.api.nvim_create_user_command(cmd_name, function(info)
    dispatch(info.fargs[1] or "")
  end, {
    desc     = "[buffer-ctx] Line-mark operations: toggle / yank",
    nargs    = "?",
    complete = function(arglead) return complete(arglead) end,
  })

  -- Compat commands (preserve wkdoptions.ui.line_marker API)
  vim.api.nvim_create_user_command("MarkLineToggle", function()
    M.toggle(vim.api.nvim_win_get_cursor(0)[1])
  end, { desc = "[buffer-ctx compat] Toggle mark on current line" })

  vim.api.nvim_create_user_command("MarkLinesYank", function()
    M.yank()
  end, { desc = "[buffer-ctx compat] Yank all marked lines" })

  -- Optional keymaps
  local km = type(opts) == "table" and opts.keymaps or nil
  if km and km ~= false then
    if type(km.toggle) == "string" then
      vim.keymap.set("n", km.toggle, function()
        M.toggle(vim.api.nvim_win_get_cursor(0)[1])
      end, { desc = "[buffer-ctx] Mark: toggle line", silent = true })
    end
    if type(km.yank) == "string" then
      vim.keymap.set("n", km.yank, function()
        M.yank()
      end, { desc = "[buffer-ctx] Mark: yank marked lines", silent = true })
    end
  end
end

return M
