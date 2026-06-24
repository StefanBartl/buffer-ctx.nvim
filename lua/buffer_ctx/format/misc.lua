---@module 'buffer_ctx.format.misc'
---@brief Lightweight buffer-level formatting operations.
---
--- Registers: trim, sort, unique, case, indent, clear.

local notify = require("lib.nvim.notify").create("[buffer_ctx.format.misc]")

local M   = {}
local api = vim.api

-- ─────────────────────────────────────────────────────────────────────────────
-- Implementations
-- ─────────────────────────────────────────────────────────────────────────────

local function trim_whitespace()
  local buf   = api.nvim_get_current_buf()
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local new_lines, modified = {}, 0
  for _, line in ipairs(lines) do
    local trimmed = line:gsub("%s+$", "")
    new_lines[#new_lines + 1] = trimmed
    if trimmed ~= line then modified = modified + 1 end
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
  return modified
end

local function sort_lines(lines, reverse, ignore_case, numeric)
  local sorted = vim.deepcopy(lines)
  table.sort(sorted, function(a, b)
    local va = ignore_case and a:lower() or a
    local vb = ignore_case and b:lower() or b
    if numeric then
      local na = tonumber(va:match("^%s*(%d+)"))
      local nb = tonumber(vb:match("^%s*(%d+)"))
      if na and nb then return reverse and na > nb or na < nb end
    end
    return reverse and va > vb or va < vb
  end)
  return sorted
end

local function unique_lines(lines, ignore_case)
  local seen, uniq, removed = {}, {}, 0
  for _, line in ipairs(lines) do
    local key = ignore_case and line:lower() or line
    if not seen[key] then
      seen[key] = true; uniq[#uniq + 1] = line
    else
      removed = removed + 1
    end
  end
  return uniq, removed
end

local function change_case(text, mode)
  if     mode == "upper"    then return text:upper()
  elseif mode == "lower"    then return text:lower()
  elseif mode == "title"    then
    return text:gsub("(%a)([%w_']*)", function(f, r) return f:upper() .. r:lower() end)
  elseif mode == "sentence" then
    local r = text:lower()
    r = r:gsub("^%l", string.upper)
    r = r:gsub("([.!?]%s+)(%l)", function(p, l) return p .. l:upper() end)
    return r
  end
  return text
end

local function fix_indentation(lines, use_spaces, width)
  local fixed = {}
  for _, line in ipairs(lines) do
    if line:match("^%s*$") then
      fixed[#fixed + 1] = ""
    else
      local indent_str = line:match("^%s*") or ""
      local content    = line:sub(#indent_str + 1)
      local level      = 0
      for ch in indent_str:gmatch(".") do
        if     ch == "\t" then level = level + 1
        elseif ch == " "  then level = level + (1 / width)
        end
      end
      level = math.floor(level + 0.5)
      local new_indent = use_spaces and string.rep(" ", level * width) or string.rep("\t", level)
      fixed[#fixed + 1] = new_indent .. content
    end
  end
  return fixed
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Subcommand registration
-- ─────────────────────────────────────────────────────────────────────────────

---@param register_fn fun(name: string, def: table): nil
function M.register_subcommands(register_fn)
  register_fn("clear", {
    handler = function()
      api.nvim_buf_set_lines(api.nvim_get_current_buf(), 0, -1, false, {})
      notify.info("Buffer cleared")
    end,
    complete = function() return {} end,
    nargs = "0",
    desc  = "Clear buffer content",
  })

  register_fn("trim", {
    handler = function()
      local count = trim_whitespace()
      notify.info(string.format("Trimmed trailing whitespace on %d line(s)", count))
    end,
    complete = function() return {} end,
    nargs = "0",
    desc  = "Remove trailing whitespace from buffer",
  })

  register_fn("sort", {
    handler = function(args)
      local reverse     = vim.tbl_contains(args, "-r") or vim.tbl_contains(args, "--reverse")
      local ignore_case = vim.tbl_contains(args, "-i") or vim.tbl_contains(args, "--ignore-case")
      local numeric     = vim.tbl_contains(args, "-n") or vim.tbl_contains(args, "--numeric")
      local buf         = api.nvim_get_current_buf()
      local lines       = api.nvim_buf_get_lines(buf, 0, -1, false)
      api.nvim_buf_set_lines(buf, 0, -1, false, sort_lines(lines, reverse, ignore_case, numeric))
      notify.info("Buffer sorted")
    end,
    complete = function(arg_lead)
      local opts = { "-r", "--reverse", "-i", "--ignore-case", "-n", "--numeric" }
      local out  = {}
      for _, opt in ipairs(opts) do
        if vim.startswith(opt, arg_lead) then out[#out + 1] = opt end
      end
      return out
    end,
    nargs = "*",
    desc  = "Sort buffer lines: sort [-r] [-i] [-n]",
  })

  register_fn("unique", {
    handler = function(args)
      local ignore_case = vim.tbl_contains(args, "-i") or vim.tbl_contains(args, "--ignore-case")
      local buf         = api.nvim_get_current_buf()
      local lines       = api.nvim_buf_get_lines(buf, 0, -1, false)
      local uniq, removed = unique_lines(lines, ignore_case)
      api.nvim_buf_set_lines(buf, 0, -1, false, uniq)
      notify.info(string.format("Removed %d duplicate line(s)", removed))
    end,
    complete = function(arg_lead)
      if vim.startswith("--ignore-case", arg_lead) then return { "--ignore-case" } end
      if vim.startswith("-i",            arg_lead) then return { "-i" }            end
      return {}
    end,
    nargs = "*",
    desc  = "Remove duplicate buffer lines: unique [-i]",
  })

  register_fn("case", {
    handler = function(args)
      if #args == 0 then
        notify.error("[case] Usage: case <upper|lower|title|sentence>")
        return
      end
      local mode        = args[1]
      local valid_modes = { "upper", "lower", "title", "sentence" }
      if not vim.tbl_contains(valid_modes, mode) then
        notify.error("[case] Invalid mode: " .. mode)
        return
      end
      local buf   = api.nvim_get_current_buf()
      local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
      local new_lines = {}
      for _, line in ipairs(lines) do new_lines[#new_lines + 1] = change_case(line, mode) end
      api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
      notify.info(string.format("Changed to %s case", mode))
    end,
    complete = function() return { "upper", "lower", "title", "sentence" } end,
    nargs = "1",
    desc  = "Change case: case <upper|lower|title|sentence>",
  })

  register_fn("indent", {
    handler = function(args)
      local use_spaces = vim.bo.expandtab
      local width      = vim.bo.shiftwidth > 0 and vim.bo.shiftwidth or vim.bo.tabstop
      if vim.tbl_contains(args, "--spaces") then use_spaces = true  end
      if vim.tbl_contains(args, "--tabs")   then use_spaces = false end
      for _, arg in ipairs(args) do
        local w = tonumber(arg)
        if w then width = w end
      end
      local buf   = api.nvim_get_current_buf()
      local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
      api.nvim_buf_set_lines(buf, 0, -1, false, fix_indentation(lines, use_spaces, width))
      notify.info(string.format("Fixed indentation (%s, width=%d)", use_spaces and "spaces" or "tabs", width))
    end,
    complete = function(arg_lead)
      local opts = { "--spaces", "--tabs", "2", "4", "8" }
      local out  = {}
      for _, opt in ipairs(opts) do
        if vim.startswith(opt, arg_lead) then out[#out + 1] = opt end
      end
      return out
    end,
    nargs = "*",
    desc  = "Fix indentation: indent [--spaces|--tabs] [width]",
  })
end

return M
