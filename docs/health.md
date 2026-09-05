# Health

```vim
:checkhealth buffer_ctx
```

Three sections, `buffer_ctx` first and always run; `buffer_ctx.format` and
`buffer_ctx.mark` each stop early (`info`, not `warn`) when that subsystem is
disabled in `opts` — a disabled subsystem isn't a problem to report on.

## `buffer_ctx`

| Check | ok | warn / info |
|---|---|---|
| Neovim version | `>= 0.9` | warn: `0.9+ recommended` |
| libuv | `vim.uv` or `vim.loop` present | warn: not found |
| `vim.fn.setreg` | present (clipboard ops need it) | warn: unavailable |
| Plugin guard | `vim.g.loaded_buffer_ctx` set | warn: `setup()` was never called |
| lib.nvim (command layer) | detected — `:Insert`/`:Copy`/`:Format`/`:Mark` can register | warn: not found, commands will fail to register |
| lib.nvim (notify) | detected — using `lib.nvim.notify` | info: using plain `vim.notify` |
| lib.nvim (keymap) | detected — using `lib.nvim.bindings.keymap` | info: using plain `vim.keymap.set` |
| which-key.nvim | detected — `<leader>cn` group label registered | info: not found, keymaps still work |
| `buffer_ctx.bindings` | loaded | warn: failed to load |
| `:Insert` / `:Copy` route health | delegated to `lib.nvim`'s composer (`composer.checkhealth("Insert"\|"Copy")`) | — |
| `:CopyFilepathAbsolute` / `:CopyFilepathRelative` | compat commands registered | warn: not found |

lib.nvim is the one **required** dependency here — everything else in this
section (notify, keymap, which-key) is cosmetic and degrades gracefully, which
is why those three are `info` rather than `warn` when absent.

## `buffer_ctx.format`

Skipped (with a single `info` line) when `opts.format = false` or
`opts.format.enable = false`.

| Check | ok | warn |
|---|---|---|
| `:Format` command | registered | not found — call `setup()` first |
| Each of `column_align`, `table_fmt`, `text_width`, `filter_lines`, `enum_lines`, `misc` | module loaded | failed to load, with the module path |
| `:Format` route health | delegated to `composer.checkhealth("Format")` | — |

## `buffer_ctx.mark`

Skipped (with a single `info` line) when `opts.mark = false` or
`opts.mark.enable = false`.

| Check | ok | warn |
|---|---|---|
| `:Mark` command | registered | not found — call `setup()` first |
| `:MarkLineToggle` compat command | registered | not found |
| `buffer_ctx.mark` module | loaded | failed to load |
| `:Mark` route health | delegated to `composer.checkhealth("Mark")` | — |

Note: `:MarkLinesYank` (the `:Mark yank` compat alias) is not checked here —
only `:MarkLineToggle` is. Both are registered back-to-back in the same
`mark/init.lua` setup function, so in practice a missing `:MarkLineToggle`
means the pair failed together.
