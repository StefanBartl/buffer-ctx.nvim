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
