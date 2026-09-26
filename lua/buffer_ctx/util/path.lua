---@module 'buffer_ctx.util.path'
--- Pure path helpers: module-path derivation, cwd-relative paths, separator
--- normalization, and depth-limited segment slicing.

local M = {}
local fn = vim.fn

-- Soft dependency, matching util/notify.lua's convention: prefer lib.nvim's
-- version when installed, fall back to the original local implementation.
local ok_lib_mod, lib_get_module_path = pcall(require, "lib.nvim.lua_ls.get_module_path")
local ok_lib_sep, lib_unify_slashes = pcall(require, "lib.nvim.cross.fs.separators.unify_slashes")

-- Windows (and the env vars/stdpath values it hands back) compares paths
-- case-insensitively, and the drive letter alone can differ in case between
-- e.g. $REPOS_DIR and what fnamemodify(":p") reports for a file under it --
-- a case-sensitive compare would just never match there. Resolved once at
-- require time since it cannot change over the life of the process (mirrors
-- filetree.nvim's util/path.lua:env_rooted).
local IS_WINDOWS = fn.has("win32") == 1

---Derive the Lua module path from an absolute file path
--- "/…/lua/foo/bar/init.lua" → "foo.bar"
---@param filepath string
---@return string|nil
function M.get_module_path(filepath)
  if ok_lib_mod then
    return lib_get_module_path(filepath)
  end
  local norm = (filepath:gsub("\\", "/"))
  local lua_idx = norm:find("/lua/")
  if not lua_idx then
    return nil
  end
  local after = norm:sub(lua_idx + 5)
  local trimmed = (after:gsub("%.lua$", ""):gsub("/init$", ""))
  -- Parenthesized: gsub returns (string, count); only the string is the result.
  return (trimmed:gsub("/", "."))
end

---Return a path relative to cwd (strips leading "./"), forward-slashed
---@param abs_path string
---@return string
function M.relative_to_cwd(abs_path)
  local rel = fn.fnamemodify(abs_path, ":."):gsub("\\", "/")
  if rel:sub(1, 2) == "./" then
    rel = rel:sub(3)
  end
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
  for p in norm:gmatch("[^/]+") do
    parts[#parts + 1] = p
  end
  local n = #parts
  local start = math.max(1, n - count + 1)
  local result = {}
  for i = start, n do
    result[#result + 1] = parts[i]
  end
  return result
end

---Return `abs_path`'s remainder after stripping `root`, or nil when
---`abs_path` does not live under `root` (also nil when `root` is nil, empty,
---or not a string). A trailing separator on `root` is ignored, and the
---comparison folds case on Windows (see `IS_WINDOWS` above). This is the one
---place mode="nvim"/"repos"/"env" in ops/filepath.lua and
---`is_inside_nvim_config` below all do their root matching, instead of each
---reimplementing (and subtly diverging on) the same prefix check.
---@param abs_path string
---@param root string|nil
---@return string|nil rest  "" when abs_path == root, nil when not under root
---@return integer|nil root_len  length of the normalized, matched root
function M.strip_root(abs_path, root)
  if type(root) ~= "string" or root == "" then
    return nil
  end
  local norm_path = abs_path:gsub("\\", "/")
  local norm_root = (root:gsub("\\", "/")):gsub("/+$", "")
  if norm_root == "" then
    return nil
  end
  local folded_path, folded_root = norm_path, norm_root
  if IS_WINDOWS then
    folded_path, folded_root = norm_path:lower(), norm_root:lower()
  end
  if folded_path == folded_root then
    return "", #norm_root
  end
  if folded_path:sub(1, #folded_root + 1) == folded_root .. "/" then
    return norm_path:sub(#norm_root + 2), #norm_root
  end
  return nil
end

---Check whether an absolute path lives inside the Neovim config directory
---@param abs_path string
---@return boolean
function M.is_inside_nvim_config(abs_path)
  return M.strip_root(abs_path, fn.stdpath("config")) ~= nil
end

return M
