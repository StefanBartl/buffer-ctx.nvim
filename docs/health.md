# Health

```vim
:checkhealth buffer_ctx
```

Four sections, `buffer_ctx` first and always run; `buffer_ctx.format`,
`buffer_ctx.mark` and `buffer_ctx.reveal` each report a single `info` line
(not `warn`) instead of their per-command checks when that subsystem is
disabled in `opts` — a disabled subsystem isn't a problem to report on, and
none of the three early-`return`s out of `M.check()` itself, since a later
section (or, for `mark`, the fixed sibling `reveal` section right after it)
still has to run.

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
| markdown.nvim | detected — `:Insert`/`:Copy mdlink` delegates to its link builder | info: not found, `mdlink` falls back to a literal `[title](path)` |
| images.nvim | detected — `:Insert imagepaste` can dispatch | info: not found, `:Insert imagepaste` will fail (no local fallback) |
| `buffer_ctx.bindings` | loaded | warn: failed to load |
| `:Insert` / `:Copy` route health | delegated to `lib.nvim`'s composer (`composer.checkhealth("Insert"\|"Copy")`) | — |
| `:CopyFilepathAbsolute` / `:CopyFilepathRelative` / `:CopyFilepathRepos` / `:CopyFilepathEnv` | compat commands registered | warn: not found |

lib.nvim is the one **required** dependency here — everything else in this
section (notify, keymap, which-key, markdown.nvim) is cosmetic and degrades
gracefully, which is why those are `info` rather than `warn` when absent.
images.nvim is the one exception among the optional deps in this section:
`:Insert imagepaste` genuinely fails without it (its clipboard-read pipeline
has no local fallback here, see [commands.md](commands.md)) — still `info`,
not `warn`, since the rest of `:Insert`/`:Copy` is entirely unaffected by its
absence.

## `buffer_ctx.format`

Skipped (with a single `info` line) when `opts.format = false` or
`opts.format.enable = false`.

| Check | ok | warn |
|---|---|---|
| `:Format` command | registered | not found — call `setup()` first |
| Each of `column_align`, `table_fmt`, `text_width`, `filter_lines`, `enum_lines`, `blank_lines`, `misc` | module loaded | failed to load, with the module path |
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

## `buffer_ctx.reveal`

Skipped (a single `info` line, per-command checks omitted) when
`opts.reveal = false` or `opts.reveal.enable = false`.

| Check | ok | warn / info / error |
|---|---|---|
| `:RevealInFm` command | registered | info: not found — call `setup()` first |
| `:OpenInBrowser` command | registered | info: not found — call `setup()` first |
| `lib.nvim.cross.reveal_in_fm` | detected | **error**: not found — `:RevealInFm` will fail |
| open.nvim / `vim.ui.open` | open.nvim detected (ok) | info: open.nvim absent, `vim.ui.open` fallback available; warn: neither available — `:OpenInBrowser` will fail |

`lib.nvim.cross.reveal_in_fm` is the one **required** dependency for this
subsystem (same standing as `lib.nvim`'s command layer in the main
`buffer_ctx` section above) — there is no local fallback for the platform
dispatch it does. open.nvim, by contrast, is a genuinely optional
dependency for `:OpenInBrowser`: `vim.ui.open` (Neovim 0.10+) covers the
same ground when open.nvim isn't installed, which is why its absence is
`info`, not `warn`, as long as `vim.ui.open` exists.
