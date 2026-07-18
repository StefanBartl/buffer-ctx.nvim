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

---Parse fargs for location subcommand
---@param args string[]
---@return BufferCtx.LocationMode
function M.parse_args(args)
  return ((args and args[1]) and args[1]:lower()) or "cwd"
end

return M
