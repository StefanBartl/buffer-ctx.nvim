---@module 'buffer_ctx.format.text_width'
---@brief Reflow (word-wrap) text in a buffer or a line range.
---
--- Exports:
---   M.reflow_buffer(bufnr, width)                    – reflow entire buffer
---   M.reflow_range(bufnr, start_line, end_line, width) – reflow a line range

local M = {}

local function wrap_words(words, width, first_prefix, cont_prefix)
  local out, cur, cur_len = {}, first_prefix or "", #(first_prefix or "")
  for _, w in ipairs(words) do
    local wlen = #w
    if cur_len == 0 then
      if wlen > width then
        table.insert(out, w)
      else
        cur = w; cur_len = wlen
      end
    else
      if cur_len + 1 + wlen <= width then
        cur = cur .. " " .. w; cur_len = cur_len + 1 + wlen
      else
        table.insert(out, cur)
        cur = cont_prefix .. w; cur_len = #cur
        if cur_len > width then
          table.insert(out, cur); cur = ""; cur_len = 0
        end
      end
    end
  end
  if cur ~= "" then table.insert(out, cur) end
  return out
end

local function paragraph_to_words(par_lines)
  local words = {}
  for _, ln in ipairs(par_lines) do
    for w in ln:gmatch("%S+") do table.insert(words, w) end
  end
  return words
end

local function detect_prefixes(first_line)
  if not first_line then return "", "" end
  local indent = first_line:match("^(%s*)") or ""
  local bullet = first_line:match("^%s*([%-%*%+]%s)") or first_line:match("^%s*(%d+[%.)]%s)")
  if bullet then
    local leader = indent .. bullet
    return leader, string.rep(" ", #leader)
  end
  return indent, indent
end

local function reflow_lines_region(lines, width)
  local out       = {}
  local paragraph = {}
  local para_first

  local function flush()
    if #paragraph == 0 then return end
    local fp, cp = detect_prefixes(para_first)
    local stripped = {}
    for _, l in ipairs(paragraph) do
      table.insert(stripped, (l:gsub("^%s*", "", 1)))
    end
    local words = paragraph_to_words(stripped)
    if #words == 0 then
      table.insert(out, "")
    else
      vim.list_extend(out, wrap_words(words, width, fp, cp))
    end
    paragraph = {}; para_first = nil
  end

  local i = 1
  while i <= #lines do
    local ln = lines[i]
    if ln:match("^%s*$") then
      if #paragraph > 0 then flush() end
      local j = i
      while j <= #lines and lines[j]:match("^%s*$") do
        table.insert(out, ""); j = j + 1
      end
      i = j
    else
      if #paragraph == 0 then para_first = ln end
      table.insert(paragraph, ln); i = i + 1
    end
  end
  if #paragraph > 0 then flush() end
  return out
end

---Reflow the whole buffer to `width`.
---@param bufnr integer|nil
---@param width integer
function M.reflow_buffer(bufnr, width)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  width = tonumber(width) or 0
  if width <= 0 then return end
  local lines     = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local new_lines = reflow_lines_region(lines, width)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
end

---Reflow only the range [start_line, end_line] (1-based, inclusive).
---@param bufnr      integer|nil
---@param start_line integer
---@param end_line   integer
---@param width      integer
function M.reflow_range(bufnr, start_line, end_line, width)
  bufnr      = bufnr or vim.api.nvim_get_current_buf()
  start_line = tonumber(start_line) or 1
  end_line   = tonumber(end_line)   or start_line
  width      = tonumber(width)      or 0
  if width <= 0 or start_line < 1 or end_line < start_line then return end
  local region   = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local new_region = reflow_lines_region(region, width)
  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, new_region)
end

return M
