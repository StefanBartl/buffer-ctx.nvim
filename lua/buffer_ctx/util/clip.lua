---@module 'buffer_ctx.util.clip'
---@see buffer_ctx.util.notify for the same soft-dependency pattern
---@see buffer_ctx.util.cursor for the insert-at-cursor sink counterpart

local notify = require("buffer_ctx.util.notify")
local M = {}

-- Soft dependency, matching util/notify.lua's convention: prefer lib.nvim's
-- clipboard helper (macOS/Linux/Windows/WSL OS-level fallback chain when a
-- plain register write fails) when installed, fall back to setreg-only.
local ok_lib_clipboard, lib_copy_to_clipboard = pcall(require, "lib.nvim.cross.copy_to_clipboard")

---Copy text to the system clipboard (+ register) and notify
---@param text string
---@param opts? { silent?: boolean }  silent suppresses only the success
--- message, so callers that report their own ("Copied N lines") do not notify
--- twice; warnings are always shown.
---@return boolean ok  false when no clipboard provider accepted the text
--- (the unnamed register is still set)
function M.copy(text, opts)
  if type(text) ~= "string" or text == "" then
    notify.warn("nothing to copy")
    return false
  end
  -- Guarded: without a clipboard provider (headless CI, minimal containers,
  -- no xclip/wl-copy) a "+" write is at best a silent no-op and at worst
  -- raises. Neither should cost the user the copy — the unnamed register
  -- below still carries the text.
  local clipboard_ok
  if ok_lib_clipboard then
    clipboard_ok = pcall(lib_copy_to_clipboard, text)
  else
    clipboard_ok = pcall(vim.fn.setreg, "+", text)
  end

  -- The unnamed register is always set directly: it's Vim's own register
  -- state, not something a clipboard helper (lib.nvim's or otherwise) owns.
  vim.fn.setreg('"', text)

  local preview = #text > 60 and (text:sub(1, 57) .. "...") or text
  if not clipboard_ok then
    notify.warn("no clipboard provider — copied to the unnamed register only: " .. preview)
  elseif not (opts and opts.silent) then
    notify.info("copied: " .. preview)
  end

  return clipboard_ok
end

return M
