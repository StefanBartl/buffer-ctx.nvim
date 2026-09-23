---@module 'buffer_ctx.ops.reveal'
--- Reveal the current buffer in the system file manager, or hand it to the
--- OS-registered application for it ("open in browser").
---
--- Both actions are side effects on an external process, not text producers
--- -- unlike every other `ops/*` module, neither has a `:Insert`/`:Copy`
--- sink to return a value to. `buffer_ctx.reveal` is the thin usercmd/keymap
--- wrapper around the two functions here (mirroring how `buffer_ctx.mark`
--- wraps `ops`-shaped logic of its own).
---@see buffer_ctx.reveal for the :RevealInFm / :OpenInBrowser wiring

local M = {}
local api = vim.api
local fn = vim.fn

---@internal
---Absolute path of the current buffer.
---@return string|nil abs, string|nil err
local function current_path()
  local name = api.nvim_buf_get_name(0)
  if not name or name == "" then
    return nil, "unnamed buffer"
  end
  return fn.fnamemodify(name, ":p"), nil
end

---Reveal the current buffer in the system file manager.
---
---Delegates to lib.nvim's `cross.reveal_in_fm`, the exact dispatcher
---filetree.nvim's `<leader>fm` and open.nvim's `:Open filemanager` handler
---already share (see that module's own header for the per-platform
---mechanics, including the Windows foreground-window raise). Unlike the
---rest of buffer-ctx.nvim's soft lib.nvim dependency (util/notify.lua,
---util/map.lua, util/path.lua), there is no local fallback here: lib.nvim's
---module doc names avoiding a second, drifting copy of that platform
---dispatch as the very reason it exists, and the composer-based command
---layer already makes lib.nvim a hard dependency for this plugin.
---@return boolean ok
---@return string|nil err
function M.fm()
  local path, path_err = current_path()
  if not path then
    return false, path_err
  end

  local ok_lib, reveal_in_fm = pcall(require, "lib.nvim.cross.reveal_in_fm")
  if not ok_lib or type(reveal_in_fm) ~= "function" then
    return false, "lib.nvim not found (required for reveal-in-file-manager)"
  end

  return reveal_in_fm(path)
end

---Open the current buffer with the OS-registered application for it -- a
---browser for an http(s) URL or an `.html` file, whatever program the OS
---associates with anything else.
---
---Prefers open.nvim's own `browser` handler when installed (soft
---dependency, matching commands.lua's `resolve_kit()` convention for
---`ui.kit`): `require("open").open("browser", "%")` hands open.nvim the
---explicit target AND scope, so it dispatches straight to its browser
---handler for the current buffer instead of running its own no-target
---context heuristic (tree node / <cfile> / <cWORD> / …) -- buffer-ctx.nvim
---always means "this buffer", nothing fuzzier. An explicit target also
---means open.nvim's opt-in target picker never intercepts the call (it only
---triggers when no target is given), so open.nvim's own (ok, err) return is
---always a definite result here, never the documented "nil, deferred to the
---picker" case.
---
---Falls back to `vim.ui.open` (built into Neovim 0.10+) when open.nvim is
---absent -- it hands the path to the OS's default handler for it, a browser
---for an URL or an `.html` file among them.
---@return boolean ok
---@return string|nil err
function M.browser()
  local ok_open, open_mod = pcall(require, "open")
  if ok_open and type(open_mod) == "table" and type(open_mod.open) == "function" then
    -- pcall guards the call itself (ERR-01), same as the vim.ui.open
    -- fallback below: open.nvim's own dispatch deliberately re-raises a
    -- misbehaving handler's error rather than swallowing it (its
    -- context.with_cache does `if not ok then error(err, 0) end`), so a
    -- buggy or misconfigured browser handler must not take this command
    -- down with it.
    local call_ok, ok_or_err, browser_err = pcall(open_mod.open, "browser", "%")
    if not call_ok then
      return false, tostring(ok_or_err)
    end
    return ok_or_err, browser_err
  end

  local path, path_err = current_path()
  if not path then
    return false, path_err
  end

  if type(vim.ui.open) ~= "function" then
    return false, "vim.ui.open unavailable (Neovim 0.10+ required without open.nvim)"
  end

  -- vim.ui.open(path) returns (SystemObj|nil, err|nil): a job handle on
  -- success, nil + a message on failure. pcall guards the call itself
  -- (ERR-01) -- an opener misconfiguration or a `vim.ui.opener` override can
  -- throw rather than return an error string.
  local ok, sys_obj_or_err, open_err = pcall(vim.ui.open, path)
  if not ok then
    return false, tostring(sys_obj_or_err)
  end
  if not sys_obj_or_err then
    return false, open_err or "vim.ui.open failed to launch"
  end
  return true, nil
end

return M
