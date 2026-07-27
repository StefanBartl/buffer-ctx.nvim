---@module 'buffer_ctx.ops.boilerplate.templates.guard'
local M = {}

---@param condition? string
---@param is_negated? boolean
---@return string[]
function M.guard(condition, is_negated)
  if not condition or condition == "" then
    condition = "condition"
  end
  local check = is_negated and ("not " .. condition) or condition
  return {
    string.format("if %s then", check),
    '  notify.error("TODO: Error message")',
    "  return nil",
    "end",
  }
end

---Interactive guard clause generation. Async: neither field is `required`,
---so `on_submit` always fires eventually (Esc on a field just keeps its
---default and moves on) -- same effective semantics as the old
---utils.process_prompts chain, just callback- instead of return-based.
---@param callback fun(lines: string[]|nil)
function M.guard_interactive(callback)
  require("lib.nvim.ui.kit").form({
    fields = {
      {
        name = "condition",
        label = "Condition to check (empty for 'condition'): ",
        default = "condition",
      },
      {
        name = "negation",
        label = "Use 'not' prefix? (y/n): ",
        default = "n",
      },
    },
    on_submit = function(values)
      callback(M.guard(values.condition, tostring(values.negation):lower() == "y"))
    end,
  })
end

return M
