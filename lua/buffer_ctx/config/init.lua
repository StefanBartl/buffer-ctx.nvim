---@module 'buffer_ctx.config'
--- Runtime configuration store for buffer-ctx.nvim.
--- Deep-merges user options over `buffer_ctx.config.DEFAULTS` and exposes a
--- single `get()` accessor so other modules never read a raw options table
--- directly.
---@see buffer_ctx.config.DEFAULTS
---@see buffer_ctx.@types

local M = {}

---@type BufferCtx.Config
local DEFAULTS = require("buffer_ctx.config.DEFAULTS")

local _active = nil

---@param user_opts? BufferCtx.Config
function M.setup(user_opts)
  if user_opts ~= nil and type(user_opts) ~= "table" then
    error("buffer_ctx.setup: expected table or nil, got " .. type(user_opts), 2)
  end
  _active = vim.tbl_deep_extend("force", DEFAULTS, user_opts or {})
end

---@return BufferCtx.Config
function M.get()
  return _active or DEFAULTS
end

return M
