---@module 'buffer_ctx.ops.location'
--- Current buffer location as "path:line" or "path:L1-L2".
---@see buffer_ctx.ops.filepath for the same path modes without the :line suffix

local M = {}
local api = vim.api
local fn = vim.fn
local pu = require("buffer_ctx.util.path")

---Every accepted path mode, in completion order (also feeds commands.lua).
---@type string[]
M.MODES = { "cwd", "abs", "lua", "nvim", "repos", "env" }

-- Modes whose path part is exactly what `:Copy filepath <mode>` yields.
local FILEPATH_MODES = { nvim = true, repos = true, env = true }

---@internal
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
    return pu.normalize_sep(abs), nil
  elseif mode == "lua" then
    return pu.get_module_path(abs) or pu.relative_to_cwd(abs), nil
  elseif FILEPATH_MODES[mode] then
    -- Root lookup (and its errors, e.g. $REPOS_DIR unset) stays in one place.
    return require("buffer_ctx.ops.filepath").get_path({ mode = mode, format = "unix" })
  end
  return pu.relative_to_cwd(abs), nil
end

---Get the current buffer location as "path:line"
---@param mode? BufferCtx.LocationMode  default "cwd"
---@return string|nil result, string|nil err
function M.get(mode)
  local filepath, err = resolve_path(mode)
  if not filepath then
    return nil, err
  end

  local win = api.nvim_get_current_win()
  local line = api.nvim_win_is_valid(win) and api.nvim_win_get_cursor(win)[1] or 1
  return filepath .. ":" .. line, nil
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

  -- commands.lua passes nil/nil for "no range given"; a non-nil line1 ==
  -- line2 is an explicit single-line range from the caller and must not be
  -- overridden by a stale visual selection elsewhere in the buffer.
  if not line1 or not line2 then
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
    return filepath .. ":" .. line1, nil
  end
  return string.format("%s:L%d-L%d", filepath, line1, line2), nil
end

---Parse fargs for location subcommand
---@param args string[]
---@return BufferCtx.LocationMode mode, boolean range, string|nil err
--- err is set when a token is neither "range" nor one of M.MODES (a typo must
--- not silently behave like "no argument given")
function M.parse_args(args)
  local mode = "cwd"
  local range = false
  local unknown = {}
  for _, a in ipairs(args or {}) do
    local lo = a:lower()
    if lo == "range" then
      range = true
    elseif vim.tbl_contains(M.MODES, lo) then
      mode = lo
    else
      unknown[#unknown + 1] = a
    end
  end
  if #unknown > 0 then
    return mode,
      range,
      string.format(
        "unknown argument(s): %s (valid: %s, range)",
        table.concat(unknown, ", "),
        table.concat(M.MODES, ", ")
      )
  end
  return mode, range, nil
end

return M
