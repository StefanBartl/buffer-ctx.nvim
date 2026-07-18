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
function M.copy(text)
  if type(text) ~= "string" or text == "" then
    notify.warn("nothing to copy")
    return
  end
  if ok_lib_clipboard then
    lib_copy_to_clipboard(text)
  else
    vim.fn.setreg("+", text)
  end
  -- The unnamed register is always set directly: it's Vim's own register
  -- state, not something a clipboard helper (lib.nvim's or otherwise) owns.
  vim.fn.setreg('"', text)
  local preview = #text > 60 and (text:sub(1, 57) .. "...") or text
  notify.info("copied: " .. preview)
end

return M
