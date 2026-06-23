---@module 'buffer_ctx.config'
local M = {}

---@type BufferCtx.Config
local DEFAULTS = {
  keymaps = {
    location_copy = "<leader>cnl",
    module_copy   = "<leader>cnm",
    filepath_copy = "<leader>cnf",
  },
  commands = true,
}

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
