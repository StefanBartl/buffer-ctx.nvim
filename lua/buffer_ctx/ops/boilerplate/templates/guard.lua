---@module 'buffer_ctx.ops.boilerplate.templates.guard'
local M = {}

---@param condition? string
---@param is_negated? boolean
---@return string[]
function M.guard(condition, is_negated)
  if not condition or condition == "" then condition = "condition" end
  local check = is_negated and ("not " .. condition) or condition
  return {
    string.format("if %s then", check),
    '  notify.error("TODO: Error message")',
    "  return nil",
    "end",
  }
end

---Interactive guard clause generation
---@return string[]|nil
function M.guard_interactive()
  local utils = require("buffer_ctx.ops.boilerplate.templates.utils")
  local values = utils.process_prompts({
    { name = "condition", prompt = "Condition to check (empty for 'condition')", default = "condition", required = false },
    { name = "negation",  prompt = "Use 'not' prefix? (y/n)",                   default = "n",         required = false },
  })
  if not values then return nil end
  return M.guard(values.condition, values.negation:lower() == "y")
end

return M
