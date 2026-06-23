---@module 'buffer_ctx'
local M = {}

local _setup_done = false

---Configure and activate buffer-ctx.nvim (idempotent)
---@param user_opts? BufferCtx.Config
function M.setup(user_opts)
  if _setup_done then return end
  _setup_done = true

  local config = require("buffer_ctx.config")
  config.setup(user_opts)
  local cfg = config.get()

  if cfg.commands ~= false then
    require("buffer_ctx.commands").register()
  end

  local km = cfg.keymaps
  if km ~= false then
    if km == true or km == nil then
      -- use defaults from config
      km = {
        location_copy = "<leader>cnl",
        module_copy   = "<leader>cnm",
        filepath_copy = "<leader>cnf",
      }
    end
    require("buffer_ctx.keymaps").attach(km)
  end

  vim.g.loaded_buffer_ctx = 1
end

-- Public API (thin wrappers — useful for Lua scripts/keymaps)

---Insert a subcommand result at cursor
---@param subcmd string
---@param args? string[]
function M.insert(subcmd, args)
  local cmds = require("buffer_ctx.commands")
  -- reuse dispatch by synthesising a fake fargs table
  cmds._dispatch(subcmd, args or {}, "cursor")
end

---Copy a subcommand result to clipboard
---@param subcmd string
---@param args? string[]
function M.copy(subcmd, args)
  local cmds = require("buffer_ctx.commands")
  cmds._dispatch(subcmd, args or {}, "clip")
end

return M
