-- .testing.lua -- configuration of testing.nvim for this project.
-- Written by `testing migrate`; edit freely (it is never overwritten). Every key is optional; the
-- keys are documented in testing.nvim's docs/CONFIG.md. Loading this file executes it (same trust
-- as running the specs).
return {
  -- Lua module root of the project.
  plugin = "buffer-ctx",
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
  -- Guards (docs/GUARDS.md): safety nets around every spec; all clean on this suite except `prompt`.
  guards = {
    fs = "error",
    state = "error",
    scheduled_error = "error",
    deprecation = "error",
    process_net = "error",
    -- Real repo bug, so `warn` and not `error`: the table-format-cwd spec relies on the headless
    -- default answer of vim.fn.confirm() (table_fmt.lua), i.e. it asks a prompt nobody answers.
    prompt = "warn",
  },
  -- What the guards let through on purpose.
  guard_allow = {
    -- The specs create throwaway git repositories (git init/commit/rev-parse/checkout) to test
    -- the repo-root detection and repos-relative paths.
    spawn = { "git" },
  },
}
