---@module 'buffer_ctx.ops.git'
--- Current git revision info for the buffer's repository.
--- Modes: hash (full SHA), short (abbreviated SHA), branch (current branch),
--- tag (nearest tag via describe). Queries run in the buffer's own directory,
--- so the result is correct even when :cd points somewhere else.
---@see buffer_ctx.ops.location for the file-position counterpart

local lib_git = require("lib.nvim.git")

local M = {}
local api = vim.api
local fn = vim.fn

---@type table<string, boolean>
local MODES = { hash = true, short = true, branch = true, tag = true }

---@internal
---Directory to run git in: the buffer's own directory, else cwd.
---@return string
local function repo_dir()
  local name = api.nvim_buf_get_name(0)
  if name and name ~= "" then
    local dir = fn.fnamemodify(name, ":p:h")
    if fn.isdirectory(dir) == 1 then
      return dir
    end
  end
  return fn.getcwd()
end

---Get git revision info for the current buffer's repository
---@param mode? BufferCtx.GitMode  default "short"
---@return string|nil result, string|nil err
function M.get(mode)
  mode = (mode or "short"):lower()
  if not MODES[mode] then
    return nil, "unknown git mode: " .. mode .. " (hash|short|branch|tag)"
  end

  if fn.executable("git") == 0 then
    return nil, "git executable not found in PATH"
  end

  local opts = { dir = repo_dir() }

  -- "branch" gets its own path: `current_branch` returns nil on a detached
  -- HEAD too (same as any other failure), and that specific case is worth
  -- naming rather than handing back a bare "could not resolve".
  if mode == "branch" then
    local branch = lib_git.current_branch(opts)
    if branch then
      return branch
    end
    if lib_git.is_detached_head(opts) then
      return nil, "detached HEAD — no current branch"
    end
    return nil, "git: could not resolve the current branch"
  end

  local value
  if mode == "hash" then
    value = lib_git.head_hash(opts)
  elseif mode == "short" then
    value = lib_git.head_short_hash(opts)
  elseif mode == "tag" then
    value = lib_git.describe(opts)
  end

  -- lib.nvim.git's convenience functions return a bare nil on any failure
  -- (not a repo, git missing, ...) with no error string -- unlike the old
  -- `systemlist` call, which folded git's own stderr diagnosis into `out`
  -- and quoted it here. That specific message is gone; only the fact of
  -- failure remains.
  if not value then
    return nil, "git: could not resolve " .. mode
  end

  return value
end

---Parse fargs for the git subcommand
---@param args string[]
---@return BufferCtx.GitMode
function M.parse_args(args)
  return ((args and args[1]) and args[1]:lower()) or "short"
end

return M
