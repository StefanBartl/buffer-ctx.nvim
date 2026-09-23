-- TESTS/reveal_spec.lua — buffer_ctx.ops.reveal (fm/browser dispatch and
-- path resolution) and buffer_ctx.reveal (usercmd registration, the
-- enable = false gate). No external process is ever actually started:
-- lib.nvim's reveal_in_fm, open.nvim's open(), and vim.ui.open are all
-- stubbed, and the argv/target/scope each would have received is asserted
-- instead of anything being spawned.

return function(H)
  local reveal_op = require("buffer_ctx.ops.reveal")
  local cwd = vim.fn.getcwd()

  ---@internal
  ---Run `fn()` with `require(name)` intercepted, restoring the real module
  ---(and `package.preload`) afterwards either way.
  ---
  ---`stub == false` simulates the dependency being genuinely absent: Lua's
  ---`require` only short-circuits on a *truthy* `package.loaded[name]` (its
  ---C implementation checks `lua_toboolean`, not "is not nil"), so merely
  ---setting `package.loaded[name] = false` does NOT stop `require` from
  ---still finding the real file on `package.path` — the entry has to be
  ---cleared instead, with `package.preload[name]` made to error the way a
  ---genuinely missing module does (the same technique gopath.nvim's own
  ---`H.with_modules` uses for this exact "module = false" case).
  ---
  ---Any other `stub` value is installed straight into `package.loaded[name]`,
  ---which `require` DOES return as-is once it is non-nil/non-false.
  ---@param name string
  ---@param stub any
  ---@param fn fun()
  local function with_module(name, stub, fn)
    local had_loaded, had_loaded_set = package.loaded[name], package.loaded[name] ~= nil
    local had_preload, had_preload_set = package.preload[name], package.preload[name] ~= nil

    package.loaded[name] = nil
    if stub == false then
      package.preload[name] = function()
        error("module '" .. name .. "' not found (test stub)", 0)
      end
    else
      package.loaded[name] = stub
    end

    local ok, err = pcall(fn)

    package.loaded[name] = had_loaded_set and had_loaded or nil
    package.preload[name] = had_preload_set and had_preload or nil

    if not ok then
      error(err, 0)
    end
  end

  -- ── fm(): unnamed buffer ───────────────────────────────────────────────
  H.scratch(nil)
  local _, unnamed_err = reveal_op.fm()
  H.ok(unnamed_err ~= nil, "reveal.fm on an unnamed buffer errors")
  H.match(unnamed_err, "unnamed buffer", "reveal.fm names the unnamed-buffer error")

  -- ── fm(): lib.nvim's reveal_in_fm is called with the buffer's abs path ──
  H.scratch(cwd .. "/lua/revealtest/thing.lua")
  do
    local seen_target
    with_module("lib.nvim.cross.reveal_in_fm", function(target)
      seen_target = target
      return true
    end, function()
      local ok = reveal_op.fm()
      H.eq(ok, true, "reveal.fm returns true when reveal_in_fm succeeds")
    end)
    H.match(
      seen_target or "",
      "lua[/\\]revealtest[/\\]thing%.lua$",
      "reveal.fm passes the buffer's own path"
    )
    H.ok(
      (seen_target or ""):match("^%a:[/\\]") or (seen_target or ""):sub(1, 1) == "/",
      "reveal.fm passes an absolute path"
    )
  end

  -- ── fm(): a failing reveal_in_fm is reported back verbatim ─────────────
  with_module("lib.nvim.cross.reveal_in_fm", function()
    return false, "no file manager found on PATH"
  end, function()
    local ok, err = reveal_op.fm()
    H.eq(ok, false, "reveal.fm returns false when reveal_in_fm fails")
    H.eq(err, "no file manager found on PATH", "reveal.fm forwards reveal_in_fm's own error")
  end)

  -- ── fm(): lib.nvim absent ───────────────────────────────────────────────
  with_module("lib.nvim.cross.reveal_in_fm", false, function()
    local ok, err = reveal_op.fm()
    H.eq(ok, false, "reveal.fm fails when lib.nvim.cross.reveal_in_fm is unavailable")
    H.match(err, "lib%.nvim not found", "reveal.fm names the missing dependency")
  end)

  -- ── browser(): open.nvim installed -- explicit target+scope, no local
  --    path resolution (open.nvim resolves "%" against the current buffer
  --    itself) ────────────────────────────────────────────────────────────
  do
    local seen_target, seen_scope
    with_module("open", {
      open = function(target, scope)
        seen_target, seen_scope = target, scope
        return true, nil
      end,
    }, function()
      local ok, err = reveal_op.browser()
      H.eq(ok, true, "reveal.browser returns true when open.nvim succeeds")
      H.eq(err, nil, "reveal.browser: no error on success")
    end)
    H.eq(seen_target, "browser", "reveal.browser asks open.nvim for its 'browser' handler")
    H.eq(seen_scope, "%", "reveal.browser scopes open.nvim to the current buffer ('%')")
  end

  -- ── browser(): open.nvim installed but its handler fails ───────────────
  with_module("open", {
    open = function()
      return false, "None of the candidates found on PATH: firefox"
    end,
  }, function()
    local ok, err = reveal_op.browser()
    H.eq(ok, false, "reveal.browser returns false when open.nvim's handler fails")
    H.eq(
      err,
      "None of the candidates found on PATH: firefox",
      "reveal.browser forwards open.nvim's own error"
    )
  end)

  -- ── browser(): open.nvim installed but its handler throws (a misbehaving
  --    or misconfigured handler in open.nvim's own registry, e.g. a bug
  --    surfaced by its context.with_cache re-raising rather than
  --    swallowing it) -- must be reported back as (false, err), not left to
  --    propagate and take the command down with it ─────────────────────────
  with_module("open", {
    open = function()
      error("boom: handler blew up", 0)
    end,
  }, function()
    local ok, err = reveal_op.browser()
    H.eq(ok, false, "reveal.browser returns false when open.nvim's handler throws")
    H.match(err, "boom", "reveal.browser reports the thrown error rather than propagating it")
  end)

  -- ── browser(): open.nvim absent, falls back to vim.ui.open ──────────────
  with_module("open", false, function()
    H.scratch(cwd .. "/lua/revealtest2/page.html")

    local seen_path
    local original_ui_open = vim.ui.open
    vim.ui.open = function(path)
      seen_path = path
      return { pid = 123 }, nil
    end
    local ok, err = reveal_op.browser()
    vim.ui.open = original_ui_open

    H.eq(ok, true, "reveal.browser falls back to vim.ui.open when open.nvim is absent")
    H.eq(err, nil, "reveal.browser: no error on a successful vim.ui.open fallback")
    H.match(
      seen_path or "",
      "lua[/\\]revealtest2[/\\]page%.html$",
      "vim.ui.open fallback receives the buffer's own path"
    )
  end)

  -- ── browser(): vim.ui.open fallback reports a nil-SystemObj failure ─────
  with_module("open", false, function()
    H.scratch(cwd .. "/lua/revealtest3/page.html")
    local original_ui_open = vim.ui.open
    vim.ui.open = function()
      return nil, "no default handler registered"
    end
    local ok, err = reveal_op.browser()
    vim.ui.open = original_ui_open

    H.eq(ok, false, "reveal.browser reports a vim.ui.open failure")
    H.eq(err, "no default handler registered", "reveal.browser forwards vim.ui.open's own error")
  end)

  -- ── browser(): vim.ui.open fallback, unnamed buffer ─────────────────────
  -- current_path() must fail BEFORE vim.ui.open is even looked at.
  with_module("open", false, function()
    H.scratch(nil)
    local original_ui_open = vim.ui.open
    vim.ui.open = nil
    local ok, err = reveal_op.browser()
    vim.ui.open = original_ui_open

    H.eq(ok, false, "reveal.browser on an unnamed buffer errors before touching vim.ui.open")
    H.match(err, "unnamed buffer", "reveal.browser names the unnamed-buffer error")
  end)

  -- ── browser(): neither open.nvim nor vim.ui.open available ──────────────
  with_module("open", false, function()
    H.scratch(cwd .. "/lua/revealtest4/page.html")
    local original_ui_open = vim.ui.open
    vim.ui.open = nil
    local ok, err = reveal_op.browser()
    vim.ui.open = original_ui_open

    H.eq(ok, false, "reveal.browser fails when neither open.nvim nor vim.ui.open exist")
    H.match(err, "vim%.ui%.open unavailable", "reveal.browser names the missing fallback")
  end)

  -- ── buffer_ctx.reveal.setup(): registers both usercmds ──────────────────
  do
    local reveal = require("buffer_ctx.reveal")
    -- `usercmd.create`'s own default is `force = true` (same idempotent
    -- redefinition nvim_create_user_command itself defaults to), so calling
    -- setup() again here is safe even though buffer_ctx.init may already
    -- have wired it once (via an earlier spec's buffer_ctx.setup() call).
    local ok = pcall(reveal.setup, { enable = true, keymaps = false })
    H.ok(ok, "buffer_ctx.reveal.setup() does not raise")
    H.eq(vim.fn.exists(":RevealInFm"), 2, "reveal.setup registers :RevealInFm")
    H.eq(vim.fn.exists(":OpenInBrowser"), 2, "reveal.setup registers :OpenInBrowser")
  end

  -- ── buffer_ctx.reveal.setup(): enable = false is a documented no-op ─────
  do
    local reveal = require("buffer_ctx.reveal")
    local ok = pcall(reveal.setup, { enable = false })
    H.ok(ok, "reveal.setup({ enable = false }) does not raise")
  end
end
