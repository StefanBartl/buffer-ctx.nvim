---@module 'buffer_ctx.config'
---@brief Runtime configuration store for buffer-ctx.nvim.
---@description
--- Deep-merges user options over `buffer_ctx.config.DEFAULTS` and exposes a
--- single `get()` accessor so other modules never read a raw options table
--- directly.

local M = {}

---@type BufferCtx.Config
local DEFAULTS = require("buffer_ctx.config.DEFAULTS")

local _active = nil

---@param user_opts? BufferCtx.Config
function M.setup(user_opts)
  _active = vim.tbl_deep_extend("force", DEFAULTS, user_opts or {})
end

---@return BufferCtx.Config
function M.get()
  return _active or DEFAULTS
end

return M
