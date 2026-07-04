-- docs/TESTS/harness.lua — tiny assertion helper shared by the spec files.
-- Returned to each spec by docs/TESTS/run.lua.

local H = {}

--- Assert equality; raises a descriptive error on mismatch (caught by the runner).
---@param a any # actual
---@param b any # expected
---@param msg string|nil
function H.eq(a, b, msg)
  if a ~= b then
    error(("FAIL %s: expected %q, got %q"):format(msg or "", tostring(b), tostring(a)), 2)
  end
end

--- Assert a truthy value.
---@param v any
---@param msg string|nil
function H.ok(v, msg)
  if not v then
    error(("FAIL %s: expected truthy, got %q"):format(msg or "", tostring(v)), 2)
  end
end

--- Assert `s` matches Lua pattern `pat`.
---@param s string
---@param pat string
---@param msg string|nil
function H.match(s, pat, msg)
  if not tostring(s):match(pat) then
    error(("FAIL %s: %q does not match pattern %q"):format(msg or "", tostring(s), pat), 2)
  end
end

--- Fresh scratch buffer, made current, named `name` (so path-derived ops have
--- something to work with) with an optional filetype.
---@param name string
---@param ft string|nil
---@return integer bufnr
function H.scratch(name, ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  if name then
    vim.api.nvim_buf_set_name(buf, name)
  end
  if ft then
    vim.bo[buf].filetype = ft
  end
  return buf
end

return H
