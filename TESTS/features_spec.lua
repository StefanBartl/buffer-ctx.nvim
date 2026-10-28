-- TESTS/features_spec.lua — the subcommands added on top of the original
-- catalog: git, bufinfo, snippet, location range, the new annotation types and
-- boilerplate templates, sticky-UTC config and env completion.

return function(H)
  local cwd = vim.fn.getcwd()

  -- ── annotation: overload / diagnostic / deprecated ───────────────────────
  local ann = require("buffer_ctx.ops.annotation")

  H.eq(
    ann.get("overload", { "fun(a:", "string):", "boolean" }),
    "---@overload fun(a: string): boolean",
    "annotation overload rejoins whitespace-split fargs"
  )
  H.eq(
    ann.get("overload", { "a:", "string" }),
    "---@overload fun(a: string)",
    "annotation overload wraps a bare signature in fun(...)"
  )
  H.eq(
    ann.get("diagnostic", { "undefined-field" }),
    "---@diagnostic disable-next-line: undefined-field",
    "annotation diagnostic"
  )
  H.eq(
    ann.get("deprecated", { "use", "M.new", "instead" }),
    "---@deprecated use M.new instead",
    "annotation deprecated keeps the full reason"
  )
  -- Deliberately outside the alias: returning an error rather than raising
  -- is the property under test.
  ---@diagnostic disable-next-line: param-type-mismatch
  local _, ann_err = ann.get("nonsense", {})
  H.ok(ann_err ~= nil, "unknown annotation type returns an error")

  -- ── bufinfo ──────────────────────────────────────────────────────────────
  local bufinfo = require("buffer_ctx.ops.bufinfo")
  local buf = H.scratch(cwd .. "/features_test.lua")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c", "d" })
  H.eq(bufinfo.get_linecount(), "4", "bufinfo linecount")
  H.eq(bufinfo.get_bufnr(), tostring(buf), "bufinfo bufnr matches current buffer")

  -- ── git ──────────────────────────────────────────────────────────────────
  local git = require("buffer_ctx.ops.git")
  H.eq(git.parse_args({}), "short", "git parse_args default")
  H.eq(git.parse_args({ "BRANCH" }), "branch", "git parse_args lowercases")
  -- Deliberately outside the alias, same reason as `ann.get` above.
  ---@diagnostic disable-next-line: param-type-mismatch
  local _, git_err = git.get("bogus")
  H.ok(git_err ~= nil, "unknown git mode returns an error")
  -- The suite runs inside this repo, so a real query must succeed.
  if vim.fn.executable("git") == 1 then
    local sha = git.get("hash")
    H.match(sha or "", "^%x%x%x%x%x%x%x+$", "git hash is a hex sha")
    local short = git.get("short")
    H.ok(short and #short < #sha, "git short is shorter than the full hash")
  end

  -- ── location range ───────────────────────────────────────────────────────
  local location = require("buffer_ctx.ops.location")
  local mode, want_range = location.parse_args({ "abs", "range" })
  H.eq(mode, "abs", "location parse_args keeps the mode alongside range")
  H.eq(want_range, true, "location parse_args detects range")
  H.eq(select(2, location.parse_args({ "cwd" })), false, "location range defaults to false")

  H.scratch(cwd .. "/lua/rng/test.lua")
  H.eq(
    location.get_range("cwd", 10, 20),
    "lua/rng/test.lua:L10-L20",
    "location get_range formats an explicit range"
  )
  H.eq(
    location.get_range("cwd", 20, 10),
    "lua/rng/test.lua:L10-L20",
    "location get_range normalises a reversed range"
  )
  H.eq(
    location.get_range("cwd", 7, 7),
    "lua/rng/test.lua:7",
    "location get_range collapses a single-line range to path:line"
  )

  -- ── snippet ──────────────────────────────────────────────────────────────
  local snippet = require("buffer_ctx.ops.snippet")
  local snip_path = vim.fn.tempname() .. ".json"
  vim.fn.writefile({
    '{ "For Loop": { "prefix": "forl",',
    '    "body": ["for ${1:i} = 1, ${2:10} do", "  $0", "end"] },',
    '  "Choice": { "prefix": "ch", "body": "local ${1|alpha,beta|} = 1" },',
    '  "Plain":  { "prefix": "pl", "body": "just text" } }',
  }, snip_path)

  snippet.set_sources({ snip_path })
  H.eq(#snippet.get_sources(), 1, "snippet sources are configurable")

  local body = snippet.get("forl")
  H.eq(body and body[1], "for i = 1, 10 do", "snippet strips ${n:default} to the default")
  H.eq(body and body[2], "  ", "snippet drops bare $0 tabstops")
  H.ok(
    vim.deep_equal(snippet.get("For Loop"), body),
    "snippet resolves by name and by prefix alike"
  )
  H.eq(snippet.get("ch")[1], "local alpha = 1", "snippet takes the first choice of ${n|a,b|}")
  H.eq(snippet.get("pl")[1], "just text", "snippet accepts a string body")

  local _, snip_err = snippet.get("does-not-exist")
  H.ok(snip_err ~= nil, "unknown snippet returns an error")

  snippet.set_sources({})
  local _, no_src = snippet.get("forl")
  H.ok(no_src ~= nil, "snippet without sources returns an error instead of crashing")
  vim.fn.delete(snip_path)

  -- ── boilerplate: new templates + describe() ──────────────────────────────
  local boiler = require("buffer_ctx.ops.boilerplate")
  local descs = boiler.describe()
  for _, key in ipairs({ "lua-test", "lua-enum", "html-table", "html-section", "md-frontmatter" }) do
    local lines, err = boiler.get(key, nil)
    H.ok(lines and #lines > 0, "boilerplate " .. key .. " renders (" .. tostring(err) .. ")")
    H.ok(descs[key] ~= nil, "boilerplate " .. key .. " has a description")
  end
  H.eq(
    boiler.get("html-section", "intro")[1],
    '<section id="#sec-intro">',
    "boilerplate honours the id arg"
  )

  -- guard-clause is interactive (asks in a kit.form, asynchronously): is_interactive() lets a caller that must not
  -- trigger a prompt as a side effect (e.g. a live-preview pane on cursor movement) detect and skip it, `get_async`
  -- is how it is generated, and `get` refuses it with a message instead of blocking.
  H.ok(boiler.is_interactive("guard-clause"), "boiler.is_interactive('guard-clause') is true")
  H.ok(not boiler.is_interactive("lua-test"), "boiler.is_interactive('lua-test') is false")
  H.ok(
    not boiler.is_interactive("does-not-exist"),
    "boiler.is_interactive(unknown key) is false, not an error"
  )
  do
    local refused_lines, refused_err = boiler.get("guard-clause", nil)
    H.eq(refused_lines, nil, "boiler.get refuses an interactive template")
    H.match(refused_err, "get_async", "and names the asynchronous call")
  end

  --- Run `get_async` and return what the callback got (nothing if it never ran).
  ---@param key string
  ---@return table|nil results  { lines, err, cancelled, calls = n }
  local function generate(key)
    local got = { calls = 0 }
    boiler.get_async(key, nil, function(lines, err, cancelled)
      got.calls = got.calls + 1
      got.lines, got.err, got.cancelled = lines, err, cancelled
    end)
    return got
  end

  do
    -- kit.form answered at once, as if the user pressed <CR> on the defaults of "ready" / "y"
    package.loaded["ui.kit"] = {
      form = function(opts)
        opts.on_submit({ condition = "ready", negation = "y" })
        return {}
      end,
    }
    package.loaded["buffer_ctx.ops.boilerplate.templates.guard"] = nil
    local got = generate("guard-clause")
    H.eq(got.calls, 1, "guard-clause: the callback ran once")
    H.eq(got.err, nil, "guard-clause: no error")
    H.ok(
      got.lines ~= nil and got.lines[1] == "if not ready then",
      "guard-clause: negation applied, condition substituted"
    )
    package.loaded["ui.kit"] = nil
    package.loaded["buffer_ctx.ops.boilerplate.templates.guard"] = nil
  end

  do
    -- ERR-11: a cancelled interactive prompt (<Esc> on the form) is not the same outcome as generation actually
    -- failing -- the third callback value lets a caller tell the two apart.
    local fields
    package.loaded["ui.kit"] = {
      form = function(opts)
        fields = opts.fields
        opts.on_cancel()
        return {}
      end,
    }
    package.loaded["buffer_ctx.ops.boilerplate.templates.guard"] = nil
    local got = generate("guard-clause")
    -- the real kit.form takes <Esc> on a field that is not `required` as "use the default" and goes on
    for _, field in ipairs(fields) do
      H.eq(
        field.required,
        true,
        "guard-clause: <Esc> on '" .. field.name .. "' dismisses the whole form"
      )
    end
    H.eq(got.lines, nil, "guard-clause cancel: no lines produced")
    H.eq(got.err, nil, "guard-clause cancel: no error object -- a cancel is not a failure")
    H.eq(
      got.cancelled,
      true,
      "guard-clause cancel: the cancelled flag distinguishes it from a failure"
    )
    package.loaded["ui.kit"] = nil
    package.loaded["buffer_ctx.ops.boilerplate.templates.guard"] = nil
  end

  do
    -- the form answers later (the editor keeps running while it is open): nothing is produced before, the callback
    -- runs once after; a form that cannot open (nil, no callbacks) is a cancel, and a form that cancels AND returns
    -- nil does not call back twice
    local submit
    package.loaded["ui.kit"] = {
      form = function(opts)
        submit = opts.on_submit
        return {}
      end,
    }
    package.loaded["buffer_ctx.ops.boilerplate.templates.guard"] = nil
    local got = generate("guard-clause")
    H.eq(got.calls, 0, "guard-clause: nothing is produced while the form is open")
    submit({ condition = "x", negation = "n" })
    H.eq(got.calls, 1, "guard-clause: the callback runs when the form is answered")
    H.eq(got.lines[1], "if x then", "guard-clause: and carries the answer")

    package.loaded["ui.kit"] = {
      form = function()
        return nil
      end,
    }
    package.loaded["buffer_ctx.ops.boilerplate.templates.guard"] = nil
    got = generate("guard-clause")
    H.eq(got.calls, 1, "guard-clause: a form that cannot open calls back once")
    H.eq(got.cancelled, true, "guard-clause: and it is a cancel")

    package.loaded["ui.kit"] = {
      form = function(opts)
        opts.on_cancel()
        return nil
      end,
    }
    package.loaded["buffer_ctx.ops.boilerplate.templates.guard"] = nil
    got = generate("guard-clause")
    H.eq(got.calls, 1, "guard-clause: cancel and nil do not call back twice")
    package.loaded["ui.kit"] = nil
    package.loaded["buffer_ctx.ops.boilerplate.templates.guard"] = nil
  end

  do
    -- LLS-31: the vim.fn.input fallback (no kit at all) used to run its second prompt unconditionally, even when the
    -- first was cancelled with CTRL-C -- a cancel must short-circuit the whole form, matching kit.form's cancel
    -- semantics above, not surface a second, unwanted prompt before finally returning nil.
    package.loaded["ui.kit"] = nil
    package.loaded["lib.nvim.ui.kit"] = { not_a_kit = true } -- loads, but has no `form`
    package.loaded["buffer_ctx.ops.boilerplate.templates.guard"] = nil
    package.preload["ui.kit"] = function()
      error("module 'ui.kit' not found")
    end

    local orig_input = vim.fn.input
    local input_calls = {}
    vim.fn.input = function(prompt, default)
      input_calls[#input_calls + 1] = prompt
      if prompt:find("Condition to check", 1, true) then
        error("CTRL-C") -- simulates the user cancelling the first prompt
      end
      return default
    end

    local got = generate("guard-clause")

    vim.fn.input = orig_input
    package.preload["ui.kit"] = nil
    package.loaded["lib.nvim.ui.kit"] = nil
    package.loaded["buffer_ctx.ops.boilerplate.templates.guard"] = nil

    H.eq(got.cancelled, true, "guard-clause fallback cancel: reported as a cancel")
    H.eq(#input_calls, 1, "guard-clause fallback cancel: the second prompt never fires")
  end

  -- ── env completion ───────────────────────────────────────────────────────
  local env_op = require("buffer_ctx.ops.env")
  vim.fn.setenv("BUFFER_CTX_SPEC_VAR", "1")
  local names = env_op.list_names()
  H.ok(#names > 0, "env list_names is non-empty")
  H.ok(vim.tbl_contains(names, "BUFFER_CTX_SPEC_VAR"), "env list_names sees a freshly set var")
  vim.fn.setenv("BUFFER_CTX_SPEC_VAR", vim.NIL) -- do not leak the variable into later specs

  -- ── sticky UTC via config ────────────────────────────────────────────────
  local timestamp = require("buffer_ctx.ops.timestamp")
  local utc_now = timestamp.format_timestamp("iso", true)
  H.match(utc_now, "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d$", "timestamp utc shape")
  H.eq(
    timestamp.format_timestamp("iso", true),
    os.date("!%Y-%m-%dT%H:%M:%S"),
    "timestamp utc matches os.date UTC"
  )

  -- ── :Insert date now takes the same [format] [--utc] grammar as timestamp ──
  vim.fn.setreg('"', "")
  require("buffer_ctx.commands")._dispatch("date", { "long" }, "clip")
  H.match(vim.fn.getreg('"'), "^%a+day, %a+ %d+, %d%d%d%d$", "date long format via dispatch")
  vim.fn.setreg('"', "")
  require("buffer_ctx.commands")._dispatch("date", {}, "clip")
  H.match(
    vim.fn.getreg('"'),
    "^%d%d%d%d%-%d%d%-%d%d$",
    "date with no args still defaults to iso-date"
  )

  -- ── filepath nvim_module alias ───────────────────────────────────────────
  -- The alias lives in the dispatch layer, so drive it the way a user would.
  H.scratch(cwd .. "/lua/aliased/mod.lua")
  vim.fn.setreg('"', "")
  require("buffer_ctx.commands")._dispatch("filepath", { "nvim_module" }, "clip")
  local aliased = vim.fn.getreg('"')
  vim.fn.setreg('"', "")
  require("buffer_ctx.commands")._dispatch("module", {}, "clip")
  H.eq(aliased, vim.fn.getreg('"'), "filepath nvim_module matches the module subcommand")
end
