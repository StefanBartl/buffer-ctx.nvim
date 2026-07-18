---@module 'buffer_ctx.ops.module'
---@see buffer_ctx.util.path.get_module_path for the path→module derivation
---@see buffer_ctx.ops.filepath for the raw-path counterpart

local M = {}
local api = vim.api
local fn = vim.fn
local pu = require("buffer_ctx.util.path")

---Get the Lua module path of the current buffer
---@return string|nil result, string|nil err
function M.get_module_path()
  local name = api.nvim_buf_get_name(0)
  if not name or name == "" then
    return nil, "unnamed buffer"
  end
  local abs = fn.fnamemodify(name, ":p")
  local mod = pu.get_module_path(abs)
  if not mod then
    return nil, "not inside a /lua/ directory"
  end
  return mod
end

---Format the module path as a Lua statement or annotation
---@param style BufferCtx.ModuleStyle
---@return string|nil result, string|nil err
function M.get_statement(style)
  local mod, err = M.get_module_path()
  if not mod then
    return nil, err
  end

  style = style or "require"
  local lo = style:lower()

  if lo == "lua_ls" or lo == "luals" then
    return string.format("---@module '%s'", mod)
  elseif lo == "js" then
    return string.format('import "%s"', mod:gsub("%.", "/"))
  elseif lo == "c" then
    return string.format('#include "%s.h"', mod:gsub("%.", "/"))
  elseif lo == "generic" then
    return mod
  else
    return string.format('require("%s")', mod)
  end
end

---Parse fargs for module subcommand
---@param args string[]
---@return BufferCtx.ModuleStyle
function M.parse_args(args)
  return (args and args[1]) and args[1]:lower() or "require"
end

return M
