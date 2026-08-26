---@module 'buffer_ctx.bindings'
--- Orchestrates buffer-ctx's core bindings: the `:Insert`/`:Copy` user
--- commands and the 3 base keymaps. The which-key group label is one field
--- in the keymap spec now, applied by lib.nvim's registry.
--- `:Format` and `:Mark` are independent subsystems and wire their own
--- commands/keymaps via `buffer_ctx.format.setup()` / `buffer_ctx.mark.setup()`
--- respectively (see `lua/buffer_ctx/init.lua`).

local M = {}

---@param cfg BufferCtx.Config
function M.setup(cfg)
  if cfg.commands ~= false then
    require("buffer_ctx.bindings.usrcmds").setup()
  end

  -- Called unconditionally, `keymaps = false` included: the registry honours
  -- that itself, and binding nothing is not the same as declaring nothing --
  -- :checkhealth and the generated docs ask what EXISTS. Resolving `true`/nil
  -- to the DEFAULTS table is no longer needed either; the defaults live in the
  -- spec, which is the only place they now exist.
  require("buffer_ctx.bindings.keymaps").attach(cfg.keymaps, cfg.which_key)

  require("buffer_ctx.bindings.autocmds").setup(cfg)
end

return M
