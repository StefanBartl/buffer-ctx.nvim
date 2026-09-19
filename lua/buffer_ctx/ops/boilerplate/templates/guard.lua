---@module 'buffer_ctx.ops.boilerplate.templates.guard'
--- Guard-clause boilerplate template, plain and interactive variants.

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
---every other template's generator -- kit.sync (ui.nvim's vim.wait bridge,
---see lib.nvim's UI-KIT-CONCEPT.md §13a) blocks on the kit.form prompt and unwraps its
---result here, so callers don't need a callback. Neither field is
---`required`, so a cancelled kit.sync (<Esc> on a field) can only happen if
---the whole form is dismissed some other way -- kit.form's own cancel value
---then falls through to the `not values` check below.
---
---Soft dependency on ui.nvim's ui.kit, matching util/notify.lua's convention
---(docs/installation.md documents ui.nvim as optional): without it, the two
---fields are collected synchronously via vim.fn.input instead, guarded by
---pcall so CTRL-C during either prompt cancels cleanly rather than raising.
---@return string[]|nil
function M.guard_interactive()
  local ok_kit, kit = pcall(require, "ui.kit")
  local values, cancelled
  if ok_kit then
    values, cancelled = kit.sync(kit.form, {
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
  else
    local ok_condition, condition =
      pcall(vim.fn.input, "Condition to check (empty for 'condition'): ", "condition")
    -- Cancel the whole form on the first prompt, like kit.form does: without
    -- this, CTRL-C here still fell through to the second vim.fn.input call
    -- instead of returning immediately.
    if not ok_condition then
      return nil
    end
    local ok_negation, negation = pcall(vim.fn.input, "Use 'not' prefix? (y/n): ", "n")
    if not ok_negation then
      return nil
    end
    values, cancelled = { condition = condition, negation = negation }, false
  end
  if cancelled or not values then
    return nil
  end
  return M.guard(values.condition, tostring(values.negation):lower() == "y")
end

return M
