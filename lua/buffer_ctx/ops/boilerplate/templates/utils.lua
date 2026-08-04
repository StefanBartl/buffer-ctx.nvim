---@module 'buffer_ctx.ops.boilerplate.templates.utils'
--- Small shared helpers for the boilerplate template modules.

local pu = require("buffer_ctx.util.path")
local M = {}

---Derive module path for current buffer (used by lua.module template)
---@return string
function M.get_module_path()
  local name = vim.api.nvim_buf_get_name(0)
  local abs = vim.fn.fnamemodify(name, ":p")
  return pu.get_module_path(abs) or "module.name"
end

return M
