-- docs/BINDINGS.lua — buffer-ctx.nvim binding cheatsheet.
--
-- A single, machine-readable overview of every keymap, user command, and
-- autocommand buffer-ctx defines. This file is DOCUMENTATION only: it is not
-- required at runtime. It mirrors the source of truth in
-- `lua/buffer_ctx/bindings/` (base keymaps + :Insert/:Copy) and the two
-- self-contained subsystems `lua/buffer_ctx/format/` and
-- `lua/buffer_ctx/mark/` (which own their own commands/keymaps). If you add
-- or rename a binding there, update the matching entry here.
--
-- Structure:
--   keymaps   — normal-mode keymaps, grouped by owning subsystem.
--   commands  — every user command, with its subcommand catalog where
--               applicable.
--   autocmds  — autocommands registered by setup() (none at present).
--
-- All keymaps are individually configurable (or fully disabled) via
-- `require("buffer_ctx").setup({ keymaps = ..., mark = { keymaps = ... } })`.
-- See README.md → Configuration for the exact option shapes.

return {
  keymaps = {
    core = {
      { lhs = "<leader>cnl", mode = "n", action = "location_copy", desc = "Copy path:line (cwd-relative)" },
      { lhs = "<leader>cnm", mode = "n", action = "module_copy",   desc = "Copy Lua module path" },
      { lhs = "<leader>cnf", mode = "n", action = "filepath_copy", desc = "Copy filepath (cwd-relative, unix)" },
    },
    mark = {
      { lhs = "<S-m>", mode = "n", action = "toggle", desc = "Toggle mark on current line" },
      { lhs = "<C-p>", mode = "n", action = "yank",   desc = "Yank all marked lines to clipboard" },
    },
  },

  commands = {
    {
      name = "Insert",
      args = "{subcmd} [args…]",
      desc = "Insert context text at cursor",
      subcmds = {
        "filepath", "filename", "module", "timestamp", "uuid",
        "annotation", "boilerplate", "location", "env",
      },
    },
    {
      name = "Copy",
      args = "{subcmd} [args…]",
      desc = "Copy context text to clipboard",
      subcmds = {
        "filepath", "filename", "module", "timestamp", "uuid",
        "annotation", "boilerplate", "location", "env",
      },
    },
    {
      name = "Format",
      args = "{subcmd} [args…]",
      desc = "Buffer/selection formatting operations",
      subcmds = {
        "column", "table", "textwidth", "filter", "enum",
        "trim", "sort", "unique", "case", "indent", "clear",
      },
    },
    {
      name = "Mark",
      args = "{subcmd}",
      desc = "Toggle per-line marks and yank them to clipboard",
      subcmds = { "toggle", "yank" },
    },
    { name = "MarkLineToggle", args = nil, desc = "Compat alias for :Mark toggle" },
    { name = "MarkLinesYank",  args = nil, desc = "Compat alias for :Mark yank" },
  },

  autocmds = {
    -- buffer-ctx.nvim registers no autocommands at present.
    -- See lua/buffer_ctx/bindings/autocmds.lua for the extension point.
  },
}
