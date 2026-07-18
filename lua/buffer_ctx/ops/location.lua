---@module 'buffer_ctx.ops.location'
---@see buffer_ctx.ops.filepath for the same path modes without the :line suffix

local M = {}
local api = vim.api
local fn = vim.fn
local pu = require("buffer_ctx.util.path")

---Get the current buffer location as "path:line"
---@param mode? BufferCtx.LocationMode  default "cwd"
---@return string|nil result, string|nil err
function M.get(mode)
  local bufnr = api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) then
    return nil, "no valid buffer"
  end

  local name = api.nvim_buf_get_name(bufnr)
  if not name or name == "" then
    return nil, "unnamed buffer"
  end

  local win = api.nvim_get_current_win()
  local line = api.nvim_win_is_valid(win) and api.nvim_win_get_cursor(win)[1] or 1

  local abs = fn.fnamemodify(name, ":p")
  local filepath

  mode = (mode or "cwd"):lower()
  if mode == "abs" then
    filepath = pu.normalize_sep(abs)
  elseif mode == "lua" then
    filepath = pu.get_module_path(abs) or pu.relative_to_cwd(abs)
  else
    filepath = pu.relative_to_cwd(abs)
  end

  return filepath .. ":" .. line
end

---Resolve the path part of a location, without the line suffix
---@param mode? BufferCtx.LocationMode
---@return string|nil filepath, string|nil err
local function resolve_path(mode)
  local bufnr = api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) then
    return nil, "no valid buffer"
  end

  local name = api.nvim_buf_get_name(bufnr)
  if not name or name == "" then
    return nil, "unnamed buffer"
  end

  local abs = fn.fnamemodify(name, ":p")
  mode = (mode or "cwd"):lower()
  if mode == "abs" then
    return pu.normalize_sep(abs)
  elseif mode == "lua" then
    return pu.get_module_path(abs) or pu.relative_to_cwd(abs)
  end
  return pu.relative_to_cwd(abs)
end

---Get a line-range location as "path:L1-L2"
---
--- Falls back to the last visual selection ('< / '>) when no explicit range is
--- given, so `:Copy location range` works straight out of visual mode — typing
--- `:` there leaves visual mode but leaves the marks behind.
---@param mode? BufferCtx.LocationMode  default "cwd"
---@param line1? integer  range start (1-based)
---@param line2? integer  range end (1-based)
---@return string|nil result, string|nil err
function M.get_range(mode, line1, line2)
  local filepath, err = resolve_path(mode)
  if not filepath then
    return nil, err
  end

  if not line1 or not line2 or line1 == line2 then
    local vstart, vend = fn.line("'<"), fn.line("'>")
    if vstart and vend and vstart > 0 and vend > 0 and vstart ~= vend then
      line1, line2 = vstart, vend
    end
  end

  if not line1 or not line2 then
    local win = api.nvim_get_current_win()
    local cur = api.nvim_win_is_valid(win) and api.nvim_win_get_cursor(win)[1] or 1
    line1, line2 = cur, cur
  end

  if line1 > line2 then
    line1, line2 = line2, line1
  end

  -- A single line has no range to express; "path:42" is the honest answer.
  if line1 == line2 then
    return filepath .. ":" .. line1
  end
  return string.format("%s:L%d-L%d", filepath, line1, line2)
end

---Parse fargs for location subcommand
---@param args string[]
---@return BufferCtx.LocationMode mode, boolean range
function M.parse_args(args)
  local mode = "cwd"
  local range = false
  for _, a in ipairs(args or {}) do
    local lo = a:lower()
    if lo == "range" then
      range = true
    else
      mode = lo
    end
  end
  return mode, range
end

return M
