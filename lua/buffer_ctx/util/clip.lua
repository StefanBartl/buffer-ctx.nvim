---@module 'buffer_ctx.util.clip'
--- Copies text to the system clipboard, with an unnamed-register fallback.
--- Pure sink: returns status only, never notifies — callers decide whether
--- and how to report success/failure.
---@see buffer_ctx.util.notify for the sibling soft-dependency pattern
---@see buffer_ctx.util.cursor for the insert-at-cursor sink counterpart

local M = {}

-- Soft dependency, matching util/notify.lua's convention: prefer lib.nvim's
-- clipboard helper (macOS/Linux/Windows/WSL OS-level fallback chain when a
-- plain register write fails) when installed, fall back to setreg-only.
local ok_lib_clipboard, lib_copy_to_clipboard = pcall(require, "lib.nvim.cross.copy_to_clipboard")

---Copy text to the system clipboard (+ register). Does not notify; the
---caller decides whether/how to report `ok`/`err` to the user.
---@param text string
---@return boolean ok  false when nothing was copied or no clipboard provider
--- accepted the text (the unnamed register is still set in the latter case)
---@return string|nil err  human-readable reason when `ok` is false
---@return string preview  first ~60 chars of `text`, for caller-side messages
function M.copy(text)
  if type(text) ~= "string" or text == "" then
    return false, "nothing to copy", ""
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
    return false,
      "no clipboard provider — copied to the unnamed register only: " .. preview,
      preview
  end

  return true, nil, preview
end

return M
