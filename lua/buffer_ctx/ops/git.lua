---@module 'buffer_ctx.ops.git'
---@brief Current git revision info for the buffer's repository.
---@description
--- Modes: hash (full SHA), short (abbreviated SHA), branch (current branch),
--- tag (nearest tag via describe). Queries run in the buffer's own directory,
--- so the result is correct even when :cd points somewhere else.
---@see buffer_ctx.ops.location for the file-position counterpart

local M = {}
local api = vim.api
local fn = vim.fn

---@alias BufferCtx.GitMode "hash" | "short" | "branch" | "tag"

---@type table<string, string[]>
local ARGV = {
  hash = { "rev-parse", "HEAD" },
  short = { "rev-parse", "--short", "HEAD" },
  branch = { "rev-parse", "--abbrev-ref", "HEAD" },
  tag = { "describe", "--tags", "--always" },
}

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
  local argv = ARGV[mode]
  if not argv then
    return nil, "unknown git mode: " .. mode .. " (hash|short|branch|tag)"
  end

  if fn.executable("git") == 0 then
    return nil, "git executable not found in PATH"
  end

  local cmd = { "git", "-C", repo_dir() }
  vim.list_extend(cmd, argv)

  local out = fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    -- git writes its own diagnosis to stderr, which systemlist folds into out.
    local reason = (type(out) == "table" and out[1]) or "git command failed"
    return nil, "git: " .. reason
  end

  local value = type(out) == "table" and out[1] or nil
  if not value or value == "" then
    return nil, "git returned no output for mode: " .. mode
  end

  -- A detached HEAD reports the branch as literal "HEAD"; say so rather than
  -- handing back a word that looks like a branch name but isn't one.
  if mode == "branch" and value == "HEAD" then
    return nil, "detached HEAD — no current branch"
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
