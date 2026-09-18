---@module 'buffer_ctx.format.misc'
--- Lightweight buffer-level formatting operations. Each operates on the
--- whole buffer by default, or only the given command range when one is
--- supplied (":10,20Format sort" sorts lines 10-20, not the whole buffer).
---
--- Registers: trim, sort, unique, case, indent, clear.

local api = vim.api

local notify = require("buffer_ctx.util.notify")

local M = {}

-- Soft dependency, matching util/notify.lua's convention: prefer lib.nvim's
-- upper/lower/title case transform when installed, fall back to a local
-- equivalent otherwise. "sentence" mode stays local unconditionally: it
-- handles multiple sentence boundaries ([.!?]\s+), which
-- lib.lua.strings.case.change_case's "sentence" mode does not (it only
-- capitalizes the very first letter) — a real capability this module would
-- lose for any multi-sentence buffer content.
local ok_lib_case, lib_change_case = pcall(require, "lib.lua.strings.case")

-- ─────────────────────────────────────────────────────────────────────────────
-- Implementations
-- ─────────────────────────────────────────────────────────────────────────────

---@internal
---@param bufnr integer
---@param s integer  1-based, inclusive
---@param e integer  1-based, inclusive
---@return integer modified
local function trim_whitespace(bufnr, s, e)
  local lines = api.nvim_buf_get_lines(bufnr, s - 1, e, false)
  local new_lines, modified = {}, 0
  for _, line in ipairs(lines) do
    local trimmed = line:gsub("%s+$", "")
    new_lines[#new_lines + 1] = trimmed
    if trimmed ~= line then
      modified = modified + 1
    end
  end
  api.nvim_buf_set_lines(bufnr, s - 1, e, false, new_lines)
  return modified
end

---@internal
---@param lines string[]
---@param reverse boolean
---@param ignore_case boolean
---@param numeric boolean
---@return string[]
local function sort_lines(lines, reverse, ignore_case, numeric)
  local sorted = vim.deepcopy(lines)
  table.sort(sorted, function(a, b)
    local va = ignore_case and a:lower() or a
    local vb = ignore_case and b:lower() or b
    if numeric then
      local na = tonumber(va:match("^%s*(%d+)"))
      local nb = tonumber(vb:match("^%s*(%d+)"))
      if na and nb then
        if reverse then
          return na > nb
        end
        return na < nb
      end
    end
    if reverse then
      return va > vb
    end
    return va < vb
  end)
  return sorted
end

---@internal
---@param lines string[]
---@param ignore_case boolean
---@return string[] uniq, integer removed
local function unique_lines(lines, ignore_case)
  local seen, uniq, removed = {}, {}, 0
  for _, line in ipairs(lines) do
    local key = ignore_case and line:lower() or line
    if not seen[key] then
      seen[key] = true
      uniq[#uniq + 1] = line
    else
      removed = removed + 1
    end
  end
  return uniq, removed
end

---@internal
---@param text string
---@param mode string
---@return string
local function change_case(text, mode)
  if mode == "sentence" then
    local r = text:lower()
    r = r:gsub("^%l", string.upper)
    r = r:gsub("([.!?]%s+)(%l)", function(p, l)
      return p .. l:upper()
    end)
    return r
  end
  if ok_lib_case then
    return lib_change_case.change_case(text, mode)
  end
  if mode == "upper" then
    return text:upper()
  elseif mode == "lower" then
    return text:lower()
  elseif mode == "title" then
    return (text:gsub("(%a)([%w_']*)", function(f, r)
      return f:upper() .. r:lower()
    end))
  end
  return text
end

---@internal
---@param lines string[]
---@param use_spaces boolean
---@param width integer
---@return string[]
local function fix_indentation(lines, use_spaces, width)
  local fixed = {}
  for _, line in ipairs(lines) do
    if line:match("^%s*$") then
      fixed[#fixed + 1] = ""
    else
      local indent_str = line:match("^%s*") or ""
      local content = line:sub(#indent_str + 1)
      local level = 0
      for ch in indent_str:gmatch(".") do
        if ch == "\t" then
          level = level + 1
        elseif ch == " " then
          level = level + (1 / width)
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

---A command range must not be silently discarded in favor of the whole
---buffer -- an explicit `:10,20Format sort` selects lines 10-20, not
---everything. Mirrors blank_lines.lua's M.squeeze_buffer range resolution.
---@internal
---@param bufnr integer
---@param ctx { line1: integer, line2: integer }|nil
---@return integer s, integer e  1-based, inclusive
local function resolve_range(bufnr, ctx)
  local s = (ctx and ctx.line1) or 1
  local e = (ctx and ctx.line2) or api.nvim_buf_line_count(bufnr)
  if s > e then
    s, e = e, s
  end
  return s, e
end

---@param register_fn fun(name: string, def: table): nil
function M.register_subcommands(register_fn)
  register_fn("clear", {
    handler = function(_, ctx)
      local buf = api.nvim_get_current_buf()
      local s, e = resolve_range(buf, ctx)
      api.nvim_buf_set_lines(buf, s - 1, e, false, {})
      if ctx then
        notify.info(string.format("Cleared lines %d-%d", s, e))
      else
        notify.info("Buffer cleared")
      end
    end,
    complete = function()
      return {}
    end,
    nargs = "0",
    range = true,
    desc = "Clear buffer content",
  })

  register_fn("trim", {
    handler = function(_, ctx)
      local buf = api.nvim_get_current_buf()
      local s, e = resolve_range(buf, ctx)
      local count = trim_whitespace(buf, s, e)
      notify.info(string.format("Trimmed trailing whitespace on %d line(s)", count))
    end,
    complete = function()
      return {}
    end,
    nargs = "0",
    range = true,
    desc = "Remove trailing whitespace from buffer",
  })

  register_fn("sort", {
    handler = function(args, ctx)
      local reverse = vim.tbl_contains(args, "-r") or vim.tbl_contains(args, "--reverse")
      local ignore_case = vim.tbl_contains(args, "-i") or vim.tbl_contains(args, "--ignore-case")
      local numeric = vim.tbl_contains(args, "-n") or vim.tbl_contains(args, "--numeric")
      local buf = api.nvim_get_current_buf()
      local s, e = resolve_range(buf, ctx)
      local lines = api.nvim_buf_get_lines(buf, s - 1, e, false)
      api.nvim_buf_set_lines(buf, s - 1, e, false, sort_lines(lines, reverse, ignore_case, numeric))
      if ctx then
        notify.info(string.format("Sorted lines %d-%d", s, e))
      else
        notify.info("Buffer sorted")
      end
    end,
    complete = function(arg_lead)
      local opts = { "-r", "--reverse", "-i", "--ignore-case", "-n", "--numeric" }
      local out = {}
      for _, opt in ipairs(opts) do
        if vim.startswith(opt, arg_lead) then
          out[#out + 1] = opt
        end
      end
      return out
    end,
    nargs = "*",
    range = true,
    desc = "Sort buffer lines: sort [-r] [-i] [-n]",
  })

  register_fn("unique", {
    handler = function(args, ctx)
      local ignore_case = vim.tbl_contains(args, "-i") or vim.tbl_contains(args, "--ignore-case")
      local buf = api.nvim_get_current_buf()
      local s, e = resolve_range(buf, ctx)
      local lines = api.nvim_buf_get_lines(buf, s - 1, e, false)
      local uniq, removed = unique_lines(lines, ignore_case)
      api.nvim_buf_set_lines(buf, s - 1, e, false, uniq)
      notify.info(string.format("Removed %d duplicate line(s)", removed))
    end,
    complete = function(arg_lead)
      if vim.startswith("--ignore-case", arg_lead) then
        return { "--ignore-case" }
      end
      if vim.startswith("-i", arg_lead) then
        return { "-i" }
      end
      return {}
    end,
    nargs = "*",
    range = true,
    desc = "Remove duplicate buffer lines: unique [-i]",
  })

  register_fn("case", {
    handler = function(args, ctx)
      if #args == 0 then
        notify.error("[case] Usage: case <upper|lower|title|sentence>")
        return
      end
      local mode = args[1]
      local valid_modes = { "upper", "lower", "title", "sentence" }
      if not vim.tbl_contains(valid_modes, mode) then
        notify.error("[case] Invalid mode: " .. mode)
        return
      end
      local buf = api.nvim_get_current_buf()
      local s, e = resolve_range(buf, ctx)
      local lines = api.nvim_buf_get_lines(buf, s - 1, e, false)
      local new_lines = {}
      for _, line in ipairs(lines) do
        new_lines[#new_lines + 1] = change_case(line, mode)
      end
      api.nvim_buf_set_lines(buf, s - 1, e, false, new_lines)
      notify.info(string.format("Changed to %s case", mode))
    end,
    complete = function()
      return { "upper", "lower", "title", "sentence" }
    end,
    nargs = "1",
    range = true,
    desc = "Change case: case <upper|lower|title|sentence>",
  })

  register_fn("indent", {
    handler = function(args, ctx)
      local use_spaces = vim.bo.expandtab
      local width = vim.bo.shiftwidth > 0 and vim.bo.shiftwidth or vim.bo.tabstop
      if vim.tbl_contains(args, "--spaces") then
        use_spaces = true
      end
      if vim.tbl_contains(args, "--tabs") then
        use_spaces = false
      end
      for _, arg in ipairs(args) do
        local w = tonumber(arg)
        if w then
          width = w
        end
      end
      local buf = api.nvim_get_current_buf()
      local s, e = resolve_range(buf, ctx)
      local lines = api.nvim_buf_get_lines(buf, s - 1, e, false)
      api.nvim_buf_set_lines(buf, s - 1, e, false, fix_indentation(lines, use_spaces, width))
      notify.info(
        string.format("Fixed indentation (%s, width=%d)", use_spaces and "spaces" or "tabs", width)
      )
    end,
    complete = function(arg_lead)
      local opts = { "--spaces", "--tabs", "2", "4", "8" }
      local out = {}
      for _, opt in ipairs(opts) do
        if vim.startswith(opt, arg_lead) then
          out[#out + 1] = opt
        end
      end
      return out
    end,
    nargs = "*",
    range = true,
    desc = "Fix indentation: indent [--spaces|--tabs] [width]",
  })
end

return M
