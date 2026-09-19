-- TESTS/config_spec.lua — buffer_ctx.config (deep-merge setup/get) and
-- buffer_ctx.health (:checkhealth report, both the enabled and the
-- subsystem-disabled early-return paths).
--
-- Runs last (see run.lua): it calls buffer_ctx.config.setup() directly,
-- bypassing buffer_ctx's own idempotent setup() guard, so it must not run
-- before a spec that depends on the default config being active. It restores
-- the defaults at the end regardless.

return function(H)
  local config = require("buffer_ctx.config")

  -- setup(nil) merges onto DEFAULTS with nothing to override.
  config.setup(nil)
  local defaults_view = config.get()
  H.eq(defaults_view.mark.sign.text, "●", "config.get default mark.sign.text")
  H.eq(defaults_view.format.command, "Format", "config.get default format.command")
  H.eq(defaults_view.which_key, true, "config.get default which_key")

  -- setup(table) deep-merges: an override to one leaf leaves its siblings
  -- (and unrelated top-level sections) at their default values.
  config.setup({ keymaps = false, mark = { command = "Mark2" } })
  local merged = config.get()
  H.eq(merged.keymaps, false, "config.setup deep-merge: keymaps override applied")
  H.eq(merged.mark.command, "Mark2", "config.setup deep-merge: mark.command override applied")
  H.eq(merged.mark.enable, true, "config.setup deep-merge: mark.enable keeps its default")
  H.eq(
    merged.mark.sign.text,
    "●",
    "config.setup deep-merge: mark.sign keeps its default (untouched sibling)"
  )
  H.eq(merged.format.enable, true, "config.setup deep-merge: unrelated section keeps its default")

  -- A non-table, non-nil user_opts is a programmer error, not a soft failure.
  local setup_ok, setup_err = pcall(config.setup, "not a table")
  H.ok(not setup_ok, "config.setup rejects a non-table, non-nil argument")
  H.match(
    tostring(setup_err),
    "expected table or nil",
    "config.setup error names the expected shape"
  )

  -- ERR-50: an unknown/mistyped key is rejected before the merge, not
  -- deep-merged in as a dead field with the default silently still in force.
  config.setup({ snipets = { paths = { "x" } }, mark = { command = "Mark3" } })
  local sanitized = config.get()
  H.eq(sanitized.snipets, nil, "config.setup: an unknown top-level key never reaches the merge")
  H.eq(sanitized.mark.command, "Mark3", "config.setup: the sibling known key still applies")
  local issues = config.issues()
  H.eq(#issues, 1, "config.issues(): exactly the one unknown key is reported")
  H.match(issues[1], "snipets", "config.issues(): the issue names the misspelled key")
  H.match(issues[1], "did you mean 'snippets'", "config.issues(): a close known key is suggested")

  config.setup({ mark = { keymap = { toggle = "<S-m>" } } })
  local nested_issues = config.issues()
  H.eq(#nested_issues, 1, "config.issues(): a misspelled nested key is reported too")
  H.match(nested_issues[1], "mark%.keymap", "config.issues(): the issue is prefixed by its parent")

  -- keymaps/format/mark also accept a plain boolean override (not just a
  -- table), which is not itself an unknown-key/wrong-type issue.
  config.setup({ keymaps = false, format = false })
  H.eq(#config.issues(), 0, "config.issues(): a documented boolean override reports no issue")
  H.eq(config.get().keymaps, false, "config.setup: boolean override on a table-shaped key applies")

  config.setup(nil)
  H.eq(#config.issues(), 0, "config.issues(): a clean setup() call reports nothing")

  -- ERR-22: a known key with a wrong-typed VALUE (not an unknown key) must
  -- degrade to its default rather than being merged in as-is -- a non-string
  -- `format.command` used to reach lib.nvim's composer.verb() unvalidated
  -- and error the whole setup() call.
  local err22_ok = pcall(config.setup, { format = { command = 42 } })
  H.ok(err22_ok, "config.setup: an invalid leaf value no longer errors setup()")
  H.eq(
    config.get().format.command,
    "Format",
    "config.setup: invalid format.command degrades to its default"
  )
  local err22_issues = config.issues()
  H.eq(#err22_issues, 1, "config.issues(): the invalid leaf value is reported")
  H.match(err22_issues[1], "format%.command", "config.issues(): the issue names the offending path")
  H.match(
    err22_issues[1],
    "must be string, got number",
    "config.issues(): the issue names expected/actual type"
  )

  -- A wrong-typed leaf inside `mark` (already guarded ad-hoc by
  -- buffer_ctx.mark itself, but previously invisible to :checkhealth).
  config.setup({
    mark = { command = 7 },
    commands = "yes",
    which_key = 1,
    timestamp = { utc = "x" },
  })
  local merged_after_err22 = config.get()
  H.eq(
    merged_after_err22.mark.command,
    "Mark",
    "config.setup: invalid mark.command degrades to its default"
  )
  H.eq(merged_after_err22.commands, true, "config.setup: invalid commands degrades to its default")
  H.eq(
    merged_after_err22.which_key,
    true,
    "config.setup: invalid which_key degrades to its default"
  )
  H.eq(
    merged_after_err22.timestamp.utc,
    false,
    "config.setup: invalid timestamp.utc degrades to its default"
  )
  H.eq(#config.issues(), 4, "config.issues(): every invalid leaf in the call is reported")

  config.setup(nil)
  H.eq(#config.issues(), 0, "config.issues(): a clean setup() call reports nothing (post ERR-22)")

  -- ── health: default config, everything enabled ────────────────────────────
  config.setup(nil)
  local health_ok = pcall(require("buffer_ctx.health").check)
  H.ok(health_ok, "health.check() does not error with the default config")

  -- ── health: format/mark both disabled — exercises the early-return branch
  -- after "subsystem disabled" for each of the two `vim.health.start` blocks.
  config.setup({ format = false, mark = false })
  local health_disabled_ok = pcall(require("buffer_ctx.health").check)
  H.ok(health_disabled_ok, "health.check() does not error with format/mark disabled")

  -- Restore the defaults so this spec leaves no global state behind, in case
  -- another spec is ever added after it.
  config.setup(nil)
end
