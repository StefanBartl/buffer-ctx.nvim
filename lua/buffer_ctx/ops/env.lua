---@module 'buffer_ctx.ops.env'
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

return M
