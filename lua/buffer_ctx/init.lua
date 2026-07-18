---@module 'buffer_ctx'
local M = {}

local _setup_done = false

---Configure and activate buffer-ctx.nvim (idempotent)
---@param user_opts? BufferCtx.Config
function M.setup(user_opts)
  if _setup_done then
    return
  end
  _setup_done = true

  local config = require("buffer_ctx.config")
  config.setup(user_opts)
  local cfg = config.get()

  require("buffer_ctx.bindings").setup(cfg)

  local fmt = cfg.format
  if fmt ~= false then
    local fmt_opts = (fmt == true or fmt == nil) and { enable = true } or fmt
    ---@cast fmt_opts { enable?: boolean, command?: string }
    require("buffer_ctx.format").setup(fmt_opts)
  end

  local mark = cfg.mark
  if mark ~= false then
    local mark_opts = (mark == true or mark == nil) and { enable = true } or mark
    ---@cast mark_opts BufferCtx.MarkConfig
    require("buffer_ctx.mark").setup(mark_opts)
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
