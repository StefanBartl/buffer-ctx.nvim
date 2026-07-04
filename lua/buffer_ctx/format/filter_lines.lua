---@module 'buffer_ctx.format.filter_lines'
---@brief Filter buffer lines based on AND-combined pattern conditions.

local M = {}

local function line_matches(line, condition)
  if type(condition) == "string" then
    return string.find(line, condition, 1, true) ~= nil
  elseif type(condition) == "table" then
    for _, str in ipairs(condition) do
      if type(str) == "string" and string.find(line, str, 1, true) then return true end
    end
    return false
  end
  return false
end

local function parse_filter_argument(arg)
  local trimmed = arg:match("^%s*(.-)%s*$") or arg
  if trimmed:match("^%{.*%}$") then
    local list = {}
    for s in trimmed:gmatch([["(.-)"]]) do list[#list + 1] = s end
    for s in trimmed:gmatch([['(.-)']]) do list[#list + 1] = s end
    return list
  end
  return trimmed
end

---Filter buffer lines based on conditions.
---@param bufnr       integer
---@param conditions  (string|string[])[]  each entry is a substring, or a list of substrings (OR-matched)
---@param remove_flag boolean  true → remove matching, false → keep matching
---@return boolean, string|nil
function M.filter_lines(bufnr, conditions, remove_flag)
  bufnr       = bufnr or vim.api.nvim_get_current_buf()
  remove_flag = remove_flag or false

  if not vim.api.nvim_buf_is_valid(bufnr) then return false, "Invalid buffer" end
  if #conditions == 0 then return false, "No conditions provided" end

  local lines       = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local new_lines   = {}
  local matched_any = false

  for _, line in ipairs(lines) do
    local matches_all = true
    for _, cond in ipairs(conditions) do
      if not line_matches(line, cond) then matches_all = false; break end
    end
    if matches_all then matched_any = true end
    if remove_flag then
      if not matches_all then new_lines[#new_lines + 1] = line end
    else
      if matches_all     then new_lines[#new_lines + 1] = line end
    end
  end

  if remove_flag and #new_lines == 0 and matched_any then
    return false, "Operation would remove all lines — aborted"
  end
  if not remove_flag and not matched_any then
    return false, "No lines matched the given conditions"
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
  return true, nil
end

---Parse raw command-line args into (remove_flag, conditions).
---@param args string[]
---@return boolean remove_flag, (string|string[])[] conditions
function M.parse_filter_args(args)
  local remove_flag = false
  local conditions  = {}
  for _, arg in ipairs(args) do
    if arg == "--remove" or arg == "-r" then
      remove_flag = true
    else
      conditions[#conditions + 1] = parse_filter_argument(arg)
    end
  end
  return remove_flag, conditions
end

return M
