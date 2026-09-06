# buffer-ctx.nvim — Binding Cheatsheet

Every keymap, user command, and autocommand `buffer-ctx.nvim` defines. Kept in sync with `lua/buffer_ctx/bindings/` (base keymaps + `:Insert`/`:Copy`) and the self-contained `lua/buffer_ctx/format/` and `lua/buffer_ctx/mark/` subsystems (which own their own commands/keymaps).

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
| `<S-m>` | n | toggle | Toggle mark on current line, or N lines with a count |
| `<C-p>` | n | yank | Yank all marked lines to clipboard |
| *(unset)* | n | clear | Remove every mark in the buffer |

**A count marks that many lines.** `3<S-m>` covers the cursor line and the two
below it, clamped to the end of the buffer. Without a count it is the
single-line toggle it has always been.

Over a range — a count, or `:'<,'>Mark toggle` — this is deliberately *not* a
per-line toggle: over a partially marked selection, toggling each line leaves
a checkerboard, which looks broken rather than useful. If any line in the
range is unmarked (or marked in another category), the whole range is marked;
only when every line already carries that category does the range unmark.

---

## User Commands

| name | args | desc |
| --- | --- | --- |
| `:Insert` | `{subcmd} [args…]` | Insert context text at cursor |
| `:Copy` | `{subcmd} [args…]` | Copy context text to clipboard |
| `:CopyFilepathAbsolute` | — | Compat alias for `:Copy filepath absolute` |
| `:CopyFilepathRelative` | — | Compat alias for `:Copy filepath relative` |
| `:Format` | `{subcmd} [args…]` | Buffer/selection formatting operations |
| `:Mark` | `{subcmd} [category]` | Toggle per-line marks, clear them, and yank them to clipboard. `:Mark toggle` accepts a range (`:'<,'>Mark toggle`). `toggle`/`clear`/`yank` all take an optional category name, tab-completed from the configured ones. |
| `:MarkLineToggle` | — | Compat alias for `:Mark toggle` |
| `:MarkLinesYank` | — | Compat alias for `:Mark yank` |

---

### Subcommand catalog

| command | subcmds |
| --- | --- |
| `:Insert` | `filepath`, `filename`, `module`, `timestamp`, `date`, `uuid`, `annotation`, `boilerplate`, `snippet`, `location`, `env`, `git`, `linecount`, `bufnr` |
| `:Copy` | same catalog as `:Insert` |
| `:Format` | `column`, `table`, `textwidth`, `filter`, `enum`, `trim`, `sort`, `unique`, `case`, `indent`, `clear`, `squeeze` |
| `:Mark` | `toggle`, `yank` |

`filepath` also accepts `nvim_module` as an alias for the `module` subcommand.
`location` and `Format squeeze` accept a command range (`:'<,'>` / `:L1,L2`);
`location` additionally takes a `range` arg to switch its output to
`path:L1-L2`. See [commands.md](commands.md) for full per-subcommand args.

---

## Autocommands

| event(s) | augroup | action |
| --- | --- | --- |
| `BufDelete`, `BufWipeout` | `BufferCtxMarkCleanup` | Clear `:Mark` state for the deleted/wiped buffer, so it doesn't grow unbounded over a session |

Registered by `lua/buffer_ctx/mark/init.lua` when the `:Mark` subsystem is
enabled (default). `lua/buffer_ctx/bindings/autocmds.lua` remains a no-op —
an extension point for future autocmds, not currently used.

---

