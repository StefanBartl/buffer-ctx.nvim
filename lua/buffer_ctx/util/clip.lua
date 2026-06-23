---@module 'buffer_ctx.util.clip'
local notify = require("buffer_ctx.util.notify")
local M = {}

---Copy text to the system clipboard (+ register) and notify
---@param text string
function M.copy(text)
  if type(text) ~= "string" or text == "" then
    notify.warn("nothing to copy")
    return
  end
  vim.fn.setreg("+", text)
  vim.fn.setreg('"', text)
  local preview = #text > 60 and (text:sub(1, 57) .. "...") or text
  notify.info("copied: " .. preview)
end

return M
