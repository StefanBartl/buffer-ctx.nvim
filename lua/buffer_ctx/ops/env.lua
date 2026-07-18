---@module 'buffer_ctx.ops.env'
---@see buffer_ctx.commands for the completion wiring that uses M.list_names
local M = {}

---Get the value of an environment variable
---@param var string
---@return string|nil result, string|nil err
function M.get(var)
  if not var or var == "" then
    return nil, "variable name required"
  end
  -- strip leading $ if present
  var = var:match("^%$?(.+)$") or var
  local val = vim.env[var] or os.getenv(var)
  if not val then
    return nil, "$" .. var .. " is not set"
  end
  return val
end

---List the names of all set environment variables, for tab completion
---
--- Uses vim.fn.environ() rather than iterating vim.env: the latter is a
--- metatable proxy over getenv/setenv and yields nothing under pairs().
---@return string[]
function M.list_names()
  local names = {}
  for name in pairs(vim.fn.environ()) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

return M
