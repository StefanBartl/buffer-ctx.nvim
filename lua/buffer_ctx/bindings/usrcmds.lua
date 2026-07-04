---@module 'buffer_ctx.bindings.usrcmds'
---@brief Registers the `:Insert` and `:Copy` user commands.
---@description
--- `:Format` and `:Mark` are self-contained subsystems (see
--- `buffer_ctx.format` and `buffer_ctx.mark`) and register their own commands
--- from their own `setup()` — they are wired directly from
--- `buffer_ctx.init`, not from here.

local M = {}

function M.setup()
  require("buffer_ctx.commands").register()
end

return M
