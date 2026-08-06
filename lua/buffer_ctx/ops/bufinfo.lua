---@module 'buffer_ctx.ops.bufinfo'
--- Current buffer metadata: line count and buffer handle.
--- Both are plain buffer introspection, useful for documentation references
--- ("see lines 1-120") and for Lua scripting/debugging against a live handle.
---@see buffer_ctx.ops.location for the cursor-position counterpart

local M = {}
local api = vim.api

---Line count of the current buffer
---@return string|nil result, string|nil err
function M.get_linecount()
  local bufnr = api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) then
    return nil, "no valid buffer"
  end
  return tostring(api.nvim_buf_line_count(bufnr)), nil
end

---Handle (number) of the current buffer
---@return string|nil result, string|nil err
function M.get_bufnr()
  local bufnr = api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) then
    return nil, "no valid buffer"
  end
  return tostring(bufnr), nil
end

return M
