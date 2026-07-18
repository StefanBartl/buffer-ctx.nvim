---@module 'buffer_ctx.ops.boilerplate.templates.utils'
local notify = require("buffer_ctx.util.notify")
local pu = require("buffer_ctx.util.path")
local M = {}

---@class BufferCtx.Boilerplate.PromptSpec
---@field name string
---@field prompt string
---@field default? string
---@field required? boolean

---Prompt user for a single input value
---@param prompt_text string
---@param default? string
---@param required? boolean
---@return string|nil
function M.prompt_user(prompt_text, default, required)
  local input = vim.fn.input(prompt_text)
  if input == "" then
    if default then
      return default
    end
    if required then
      notify.error("required input was empty")
      return nil
    end
  end
  return input
end

---Process multiple prompts and return collected values
---@param prompts BufferCtx.Boilerplate.PromptSpec[]
---@return table<string,string>|nil
function M.process_prompts(prompts)
  local values = {}
  for _, spec in ipairs(prompts) do
    local val = M.prompt_user(spec.prompt .. ": ", spec.default, spec.required)
    if not val and spec.required then
      return nil
    end
    values[spec.name] = val or spec.default or ""
  end
  return values
end

---Derive module path for current buffer (used by lua.module template)
---@return string
function M.get_module_path()
  local name = vim.api.nvim_buf_get_name(0)
  local abs = vim.fn.fnamemodify(name, ":p")
  return pu.get_module_path(abs) or "module.name"
end

return M
