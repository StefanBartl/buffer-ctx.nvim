---@module 'buffer_ctx.ops.filepath'
local M = {}
local api = vim.api
local fn  = vim.fn
local pu  = require("buffer_ctx.util.path")

---@param opts BufferCtx.FilepathOpts
---@return string|nil result, string|nil err
function M.get_path(opts)
  local name = api.nvim_buf_get_name(0)
  if not name or name == "" then return nil, "unnamed buffer" end

  local abs = fn.fnamemodify(name, ":p")
  local base

  if opts.mode == "abs" then
    base = abs
  elseif opts.mode == "nvim" then
    local config = fn.stdpath("config")
    local norm_abs    = abs:gsub("\\", "/")
    local norm_config = (config:gsub("\\", "/"))
    if norm_abs:sub(1, #norm_config + 1) == norm_config .. "/" then
      base = norm_abs:sub(#norm_config + 2)
    else
      base = pu.relative_to_cwd(abs)
    end
    -- for nvim mode, format defaults to system
    if opts.format == "lua" then opts.format = "unix" end
  else
    base = pu.relative_to_cwd(abs)
  end

  local segments
  if opts.depth then
    segments = pu.pick_depth(base, opts.depth + 1)
  else
    local norm = base:gsub("\\", "/")
    segments = {}
    for p in norm:gmatch("[^/]+") do segments[#segments + 1] = p end
  end

  if #segments == 0 then
    segments = { fn.fnamemodify(abs, ":t") }
  end

  return M._format_segments(segments, opts.format or "unix")
end

---@param segments string[]
---@param format BufferCtx.FilepathFormat
---@return string
function M._format_segments(segments, format)
  if format == "lua" then
    local s = vim.deepcopy(segments)
    -- If a "lua" segment exists, drop everything up to and including the last one
    local lua_at = nil
    for i, seg in ipairs(s) do
      if seg == "lua" then lua_at = i end
    end
    if lua_at then
      s = vim.list_slice(s, lua_at + 1)
    end
    if #s == 0 then return "" end
    s[#s] = fn.fnamemodify(s[#s], ":r")
    local out = table.concat(s, ".")
    out = out:gsub("^lua%.", "")
    return out
  end
  local sep = "/"
  if format == "win" then
    sep = "\\"
  elseif format == "system" then
    sep = package.config:sub(1, 1)
  end
  return table.concat(segments, sep)
end

---Get just the filename (with or without extension)
---@param no_ext? boolean
---@return string|nil result, string|nil err
function M.get_filename(no_ext)
  local name = api.nvim_buf_get_name(0)
  if not name or name == "" then return nil, "unnamed buffer" end
  return fn.fnamemodify(name, no_ext and ":t:r" or ":t")
end

---Parse fargs for filepath/filename subcommands
---@param args string[]
---@return BufferCtx.FilepathOpts
function M.parse_args(args)
  local opts = { mode = "cwd", format = "unix", depth = nil }
  for _, arg in ipairs(args) do
    local lo = arg:lower()
    if lo == "abs" or lo == "absolute" then
      opts.mode = "abs"
    elseif lo == "nvim" then
      opts.mode = "nvim"
    elseif lo == "lua" then
      opts.format = "lua"
    elseif lo == "win" or lo == "windows" then
      opts.format = "win"
    elseif lo == "system" then
      opts.format = "system"
    elseif lo == "unix" or lo == "linux" then
      opts.format = "unix"
    elseif tonumber(arg) then
      opts.depth = tonumber(arg)
    end
  end
  return opts
end

return M
