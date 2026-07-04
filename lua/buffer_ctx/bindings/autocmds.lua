---@module 'buffer_ctx.bindings.autocmds'
---@brief buffer-ctx.nvim defines no autocommands at present.
---@description
--- Kept as a stable extension point and documentation anchor for
--- `docs/BINDINGS.lua`, mirroring the `bindings/` layout used across the
--- other stefanbartl/*.nvim plugins. `setup()` is a no-op today.

local M = {}

---@param _cfg BufferCtx.Config
function M.setup(_cfg) end

return M
