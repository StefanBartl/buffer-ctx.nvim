-- .testing.lua -- configuration of testing.nvim for this project.
-- Written by `testing migrate`; edit freely (it is never overwritten). Every key is optional; the
-- keys are documented in testing.nvim's docs/CONFIG.md. Loading this file executes it (same trust
-- as running the specs).
return {
  -- Lua module root of the project.
  plugin = "buffer_ctx",
  -- How the spec files are run: "auto" = sniffed per file, "h" = on the project's own TESTS/harness.lua,
  -- "script" = a self-running script in its own process.
  dialect = "h",
  -- Dependencies (directory names) put on the runtimepath: $<NAME>_DIR, .deps/<name>, ../<name>,
  -- stdpath('data')/lazy/<name>.
  deps = { "lib.nvim" },
  -- "none" = all specs in one nvim, "file" = one nvim per spec file
  -- (nothing leaks from one file into the next). "file" also resolves the state guard: the specs
  -- call setup() (user commands, keymaps, autocmds) and open buffers, which would otherwise leak
  -- from one file into the next.
  isolated = "file",
  -- Environment variables the specs read; a child editor inherits an allowlist only (never secrets).
  env_allow = { "LIB_NVIM_PATH" },
  -- Guards (docs/GUARDS.md): safety nets around every spec; all clean on this suite.
  guards = {
    fs = "error",
    state = "error",
    scheduled_error = "error",
    deprecation = "error",
    process_net = "error",
    prompt = "error",
  },
  -- What the guards let through on purpose.
  guard_allow = {
    -- The specs create throwaway git repositories (git init/commit/rev-parse/checkout) to test
    -- the repo-root detection and repos-relative paths.
    spawn = { "git" },
  },
  -- gated: a failed conformance check makes `scripts/test.sh conformance` exit 1 (docs/CONFORMANCE.md of testing.nvim)
  conformance = {
    gate = true,
    waivers = {
      {
        check = "K13",
        level = "warn",
        text = ":Copy is a prefix",
        reason = "the :CopyFilepath* family is deliberate and public (one command per path flavour); :Copy itself is the bare verb of the family, not a separate command to disambiguate",
        expires = "2027-04-14",
      },
      {
        check = "K13",
        level = "warn",
        text = ":Mark is a prefix",
        reason = "the :Mark* family (:MarkLineToggle, :MarkLinesYank) is deliberate and public; renaming would break users' mappings and muscle memory",
        expires = "2027-04-14",
      },
      {
        check = "K13",
        level = "warn",
        text = ":Open is a prefix",
        reason = "bare :Open is open.nvim's command, not this plugin's; :OpenInBrowser is a deliberate public name and renaming it would break users",
        expires = "2027-04-14",
      },
    },
  },
}
