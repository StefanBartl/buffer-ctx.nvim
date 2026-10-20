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

---@internal
---Normalise an optional line range to an ordered pair
---@param line1? integer
---@param line2? integer
---@return integer line1, integer line2
local function resolve_lines(line1, line2)
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
  return line1, line2
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

  line1, line2 = resolve_lines(line1, line2)
  -- A single line has no range to express; "path:42" is the honest answer.
  if line1 == line2 then
    return filepath .. ":" .. line1, nil
  end
  return string.format("%s:L%d-L%d", filepath, line1, line2), nil
end

---Get a permalink to the cursor line or line range on the git forge.
---
--- Links the current commit (not the branch), so the link keeps pointing at
--- the same lines. Works for the hosts `lib.nvim.git.remote` knows (GitHub,
--- GitLab, Codeberg).
---@param line1? integer  range start (1-based), nil = visual marks / cursor
---@param line2? integer  range end (1-based)
---@return string|nil url, string|nil err, string|nil warn  warn: the link was built but may be off
function M.get_remote(line1, line2)
  local name = api.nvim_buf_get_name(0)
  if not name or name == "" then
    return nil, "unnamed buffer"
  end
  if fn.executable("git") == 0 then
    return nil, "git executable not found in PATH"
  end

  local lib_git = require("lib.nvim.git")
  local remote_mod = require("lib.nvim.git.remote")
  local abs = fn.fnamemodify(name, ":p")
  local dir = fn.fnamemodify(abs, ":h")
  if fn.isdirectory(dir) == 0 then
    dir = fn.getcwd()
  end
  local opts = { dir = dir }

  if not lib_git.in_git_repo(opts) then
    return nil, "not inside a git repository"
  end
  local remote_url = lib_git.remote_url("origin", opts)
  if not remote_url then
    return nil, "git: no 'origin' remote"
  end
  local remote = remote_mod.parse_remote(remote_url)
  if not remote then
    return nil, "cannot parse the origin remote url: " .. remote_url
  end
  local kind = remote_mod.host_kind(remote.host)
  if not kind then
    return nil,
      string.format(
        "unknown git host '%s' (built in: github, gitlab, codeberg; see lib.nvim.git.remote.host_kind)",
        remote.host
      )
  end
  local rel = lib_git.relative_path(abs, opts)
  if not rel or rel == "" then
    return nil, "file is not tracked by git: no permalink possible"
  end
  local sha = lib_git.head_hash(opts)
  if not sha then
    return nil, "git: could not resolve HEAD (no commits yet?)"
  end

  line1, line2 = resolve_lines(line1, line2)
  local url = remote_mod.build(kind, remote, sha, rel, line1, line2)

  local warn
  if vim.bo.modified then
    warn = "buffer has unsaved changes: line numbers may differ from the commit"
  elseif lib_git.run({ "diff", "--quiet", "HEAD", "--", abs }, opts).code == 1 then
    -- Exit 1 is "differs"; any other failure (git error, timeout) says nothing about the file.
    warn = "file differs from HEAD: line numbers may differ from the commit"
  end
  return url, nil, warn
end

---Parse fargs for location subcommand
---@param args string[]
---@return BufferCtx.LocationMode mode, boolean range, string|nil err, boolean remote
--- err is set when a token is neither "range", "remote" nor one of M.MODES (a
--- typo must not silently behave like "no argument given"). `remote` asks for
--- a forge permalink instead of a path:line (the path mode is then unused).
function M.parse_args(args)
  local mode = "cwd"
  local range = false
  local remote = false
  local mode_given = false
  local unknown = {}
  for _, a in ipairs(args or {}) do
    local lo = a:lower()
    if lo == "range" then
      range = true
    elseif lo == "remote" then
      remote = true
    elseif vim.tbl_contains(M.MODES, lo) then
      mode = lo
      mode_given = true
    else
      unknown[#unknown + 1] = a
    end
  end
  if #unknown > 0 then
    return mode,
      range,
      string.format(
        "unknown argument(s): %s (valid: %s, range, remote)",
        table.concat(unknown, ", "),
        table.concat(M.MODES, ", ")
      ),
      remote
  end
  if remote and mode_given then
    return mode, range, "remote takes no path mode (the link is repo-relative)", remote
  end
  return mode, range, nil, remote
end

return M
