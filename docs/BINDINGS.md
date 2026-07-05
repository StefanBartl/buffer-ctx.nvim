# buffer-ctx.nvim — Binding Cheatsheet

Machine-readable overview of every keymap, user command, and autocommand defined by `buffer-ctx.nvim`. This file is documentation only and mirrors the source of truth in `lua/buffer_ctx/bindings/` (base keymaps + `:Insert`/`:Copy`) and the two self-contained subsystems `lua/buffer_ctx/format/` and `lua/buffer_ctx/mark/` (which own their own commands/keymaps). Any change there must be reflected here.

All keymaps are individually configurable (or fully disabled) via
`require("buffer_ctx").setup({ keymaps = ..., mark = { keymaps = ... } })`.
See README.md → Configuration for the exact option shapes.

## Table of content

  - [Keymaps](#keymaps)
    - [Core](#core)
    - [Mark](#mark)
  - [User Commands](#user-commands)
    - [Subcommand catalog](#subcommand-catalog)
  - [Autocommands](#autocommands)

---

## Keymaps

---

### Core

| lhs | mode | action | desc |
| --- | --- | --- | --- |
| `<leader>cnl` | n | location_copy | Copy path:line (cwd-relative) |
| `<leader>cnm` | n | module_copy | Copy Lua module path |
| `<leader>cnf` | n | filepath_copy | Copy filepath (cwd-relative, unix) |

---

### Mark

| lhs | mode | action | desc |
| --- | --- | --- | --- |
| `<S-m>` | n | toggle | Toggle mark on current line |
| `<C-p>` | n | yank | Yank all marked lines to clipboard |

---

## User Commands

| name | args | desc |
| --- | --- | --- |
| `:Insert` | `{subcmd} [args…]` | Insert context text at cursor |
| `:Copy` | `{subcmd} [args…]` | Copy context text to clipboard |
| `:Format` | `{subcmd} [args…]` | Buffer/selection formatting operations |
| `:Mark` | `{subcmd}` | Toggle per-line marks and yank them to clipboard |
| `:MarkLineToggle` | — | Compat alias for `:Mark toggle` |
| `:MarkLinesYank` | — | Compat alias for `:Mark yank` |

---

### Subcommand catalog

| command | subcmds |
| --- | --- |
| `:Insert` | `filepath`, `filename`, `module`, `timestamp`, `uuid`, `annotation`, `boilerplate`, `location`, `env` |
| `:Copy` | `filepath`, `filename`, `module`, `timestamp`, `uuid`, `annotation`, `boilerplate`, `location`, `env` |
| `:Format` | `column`, `table`, `textwidth`, `filter`, `enum`, `trim`, `sort`, `unique`, `case`, `indent`, `clear` |
| `:Mark` | `toggle`, `yank` |

---

## Autocommands

`buffer-ctx.nvim` registers no autocommands at present. See
`lua/buffer_ctx/bindings/autocmds.lua` for the extension point.

---

