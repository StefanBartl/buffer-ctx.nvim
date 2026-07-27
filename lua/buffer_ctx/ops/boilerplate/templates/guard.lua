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

---Interactive guard clause generation. Plain synchronous function, like
---every other template's generator -- kit.sync (lib.nvim's vim.wait bridge,
---see UI-KIT-CONCEPT.md §13a) blocks on the kit.form prompt and unwraps its
---result here, so callers don't need a callback. Neither field is
---`required`, so a cancelled kit.sync (<Esc> on a field) can only happen if
---the whole form is dismissed some other way -- kit.form's own cancel value
---then falls through to the `not values` check below.
---@return string[]|nil
function M.guard_interactive()
  local kit = require("lib.nvim.ui.kit")
  local values, cancelled = kit.sync(kit.form, {
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
  })
  if cancelled or not values then
    return nil
  end
  return M.guard(values.condition, tostring(values.negation):lower() == "y")
end

return M
