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

---Interactive guard clause generation. Asynchronous: the two fields are asked in a `kit.form` and `cb(lines)` is called
---when the form is answered -- `cb(nil)` when it is dismissed (<Esc>). The editor keeps running while the form is
---open; the earlier `kit.sync` blocked in `vim.wait`, during which Neovim does not run typed keys, so the form never saw
---them and the call returned after the timeout.
---
---The kit is `ui.kit` (ui.nvim's presets) or the copy in lib.nvim (one code base). Without any kit the two fields are
---collected with `vim.fn.input`, guarded by pcall so CTRL-C during either prompt cancels cleanly rather than raising.
---@param cb fun(lines: string[]|nil)
function M.guard_interactive(cb)
  local done = false
  local inner = cb
  cb = function(lines)
    if done then
      return
    end
    done = true
    inner(lines)
  end
  local kit
  for _, name in ipairs({ "ui.kit", "lib.nvim.ui.kit" }) do
    local ok_kit, mod = pcall(require, name)
    if ok_kit and type(mod) == "table" and type(mod.form) == "function" then
      kit = mod
      break
    end
  end
  if kit then
    local opened = kit.form({
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
        cb(M.guard(values.condition, tostring(values.negation):lower() == "y"))
      end,
      on_cancel = function()
        cb(nil)
      end,
    })
    if opened == nil then
      cb(nil) -- the form could not open: a cancel (the callbacks were not called)
    end
    return
  end
  local ok_condition, condition =
    pcall(vim.fn.input, "Condition to check (empty for 'condition'): ", "condition")
  -- Cancel the whole form on the first prompt, like kit.form does: a CTRL-C here must not fall through to the second
  -- vim.fn.input call.
  if not ok_condition then
    cb(nil)
    return
  end
  local ok_negation, negation = pcall(vim.fn.input, "Use 'not' prefix? (y/n): ", "n")
  if not ok_negation then
    cb(nil)
    return
  end
  cb(M.guard(condition, tostring(negation):lower() == "y"))
end

return M
