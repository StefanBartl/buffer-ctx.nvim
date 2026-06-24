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
  format = {
    enable  = true,
    command = "Format",
  },
  mark = {
    enable  = true,
    command = "Mark",
    keymaps = {
      toggle = "<S-m>",
      yank   = "<C-p>",
    },
  },
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
