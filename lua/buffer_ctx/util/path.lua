---@module 'buffer_ctx.util.path'
local M = {}
local fn = vim.fn

-- Soft dependency, matching util/notify.lua's convention: prefer lib.nvim's
-- version when installed, fall back to the original local implementation.
local ok_lib_mod, lib_get_module_path = pcall(require, "lib.nvim.lua_ls.get_module_path")
local ok_lib_sep, lib_unify_slashes = pcall(require, "lib.nvim.cross.fs.separators.unify_slashes")

---Derive the Lua module path from an absolute file path
--- "/…/lua/foo/bar/init.lua" → "foo.bar"
---@param filepath string
---@return string|nil
function M.get_module_path(filepath)
  if ok_lib_mod then
    return lib_get_module_path(filepath)
  end
  local norm = filepath:gsub("\\", "/")
  local lua_idx = norm:find("/lua/")
  if not lua_idx then return nil end
  local after = norm:sub(lua_idx + 5)
  local trimmed = after:gsub("%.lua$", ""):gsub("/init$", "")
  return trimmed:gsub("/", ".")
end

---Return a path relative to cwd (strips leading "./"), forward-slashed
---@param abs_path string
---@return string
function M.relative_to_cwd(abs_path)
  local rel = fn.fnamemodify(abs_path, ":."):gsub("\\", "/")
  if rel:sub(1, 2) == "./" then rel = rel:sub(3) end
  return rel
end

---Normalize path separators
---@param path string
---@param sep? string  default "/"
---@return string
function M.normalize_sep(path, sep)
  if (not sep or sep == "/") and ok_lib_sep then
    return lib_unify_slashes(path)
  end
  sep = sep or "/"
  return (path:gsub("[/\\]", sep))
end

---Return the last `count` segments of a path as a list
---@param path string
---@param count integer
---@return string[]
function M.pick_depth(path, count)
  local norm = path:gsub("\\", "/")
  local parts = {}
  for p in norm:gmatch("[^/]+") do parts[#parts + 1] = p end
  local n = #parts
  local start = math.max(1, n - count + 1)
  local result = {}
  for i = start, n do result[#result + 1] = parts[i] end
  return result
end

---Check whether an absolute path lives inside the Neovim config directory
---@param abs_path string
---@return boolean
function M.is_inside_nvim_config(abs_path)
  local config = fn.stdpath("config")
  local norm_path   = abs_path:gsub("\\", "/"):lower()
  local norm_config = (config:gsub("\\", "/")):lower()
  return norm_path:sub(1, #norm_config) == norm_config
end

return M
