---@module 'buffer_ctx.bindings'
---@brief Orchestrates buffer-ctx's core bindings: the `:Insert`/`:Copy`
--- user commands, the 3 base keymaps, and which-key labels.
---@description
--- `:Format` and `:Mark` are independent subsystems and wire their own
--- commands/keymaps via `buffer_ctx.format.setup()` / `buffer_ctx.mark.setup()`
--- respectively (see `lua/buffer_ctx/init.lua`).

local M = {}

---@param cfg BufferCtx.Config
function M.setup(cfg)
  if cfg.commands ~= false then
    require("buffer_ctx.bindings.usrcmds").setup()
  end

  local km = cfg.keymaps
  if km ~= false then
    if km == true or km == nil then
      km = require("buffer_ctx.config.DEFAULTS").keymaps
    end
    ---@cast km BufferCtx.KeymapConfig
    require("buffer_ctx.bindings.keymaps").attach(km)

    if cfg.which_key ~= false then
      require("buffer_ctx.bindings.which_key").setup()
    end
  end

  require("buffer_ctx.bindings.autocmds").setup(cfg)
end

return M
