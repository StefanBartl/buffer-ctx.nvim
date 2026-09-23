# Reveal

Two independent, argument-less commands that act on the current buffer's
own file: `:RevealInFm` and `:OpenInBrowser`. Unlike `:Insert`/`:Copy` they
produce no text and have no sink — the "result" is an external process
(a file manager window, a browser tab). Can be disabled entirely with
`opts.reveal = false`.

## Reveal in the system file manager

- **Tab:** true
- **Module:** `reveal/init.lua` (`M.fm`), `ops/reveal.lua` (`M.fm`)
- **Keymaps:** [`<leader>of`](../BINDINGS.md#reveal)
- **Usercmds:** `:RevealInFm`
- **Config:** `opts.reveal.keymaps.fm` (default `<leader>of`)
- **Tests:** `TESTS/reveal_spec.lua`

Delegates to lib.nvim's `cross.reveal_in_fm` — the exact dispatcher
filetree.nvim's `<leader>fm` (inside a *tree* buffer) and open.nvim's
`:Open filemanager` handler already share, so a fix there lands here too.
A file is selected inside its parent directory; the platform-specific
mechanics (including the Windows foreground-window raise that a plain
`explorer.exe` spawn from a terminal Neovim cannot do on its own) all live
in that one shared module, not duplicated here.

No local fallback: `lib.nvim` is already a hard dependency for this
plugin's `:Insert`/`:Copy`/`:Format`/`:Mark` command layer
(`lib.nvim.bindings.usercmd.composer`), so requiring it again for
`cross.reveal_in_fm` adds no new dependency risk.

## Open in the browser

- **Tab:** true
- **Module:** `reveal/init.lua` (`M.browser`), `ops/reveal.lua` (`M.browser`)
- **Keymaps:** [`<leader>ob`](../BINDINGS.md#reveal)
- **Usercmds:** `:OpenInBrowser`
- **Config:** `opts.reveal.keymaps.browser` (default `<leader>ob`)
- **Tests:** `TESTS/reveal_spec.lua`

Opens the current buffer with the OS-registered application for it — a
browser for a URL-shaped buffer or an `.html` file, whatever program the OS
associates with anything else.

Prefers [open.nvim](https://github.com/StefanBartl/open.nvim)'s own
`browser` handler when it is installed (soft dependency, the same
`pcall(require, ...)` convention `buffer_ctx.commands`'s `resolve_kit()`
uses for `ui.kit`):

```lua
require("open").open("browser", "%")
```

Both the target (`"browser"`) and the scope (`"%"`, the current buffer) are
given explicitly, so open.nvim dispatches straight to its browser handler
instead of running its own no-target context heuristic (tree node /
`<cfile>` / `<cWORD>` / …) — buffer-ctx.nvim always means "this buffer",
nothing fuzzier. An explicit target also means open.nvim's opt-in target
picker (`picker.enabled`, off by default) never intercepts the call, since
that picker only activates when no target is given.

Without open.nvim, falls back to `vim.ui.open` (built into Neovim 0.10+),
which hands the path to the OS's own default handler for it.

## Why two commands, not one `:Reveal {subcmd}` tree

Every other multi-action subsystem here (`:Format`, `:Mark`) has several
related sub-operations that share a subcommand tree, tab completion, and a
`lib.nvim.bindings.usercmd.composer` verb. `:RevealInFm` and `:OpenInBrowser`
take no arguments and share no state — a composer verb would add a
subcommand-routing layer with nothing for it to route. Each is instead
registered directly through `lib.nvim.bindings.usercmd` (the same
non-composer helper backing the compat commands in `buffer_ctx.commands`
and `buffer_ctx.mark`, e.g. `:CopyFilepathAbsolute` / `:MarkLineToggle`).

## Why the keymaps aren't `<leader>fm`

`<leader>fm` reads like the obvious mnemonic — it's filetree.nvim's own
default for the identical "reveal in file manager" action — but it is
already bound in this config to a different, global action ("Format
file"), so reusing it here would silently shadow that binding for every
normal buffer. `<leader>of`/`<leader>ob` ("open → file manager" / "open →
browser") were free across the whole ecosystem at the time this feature was
added; see [BINDINGS.md](../BINDINGS.md#reveal) for the exact keys.
