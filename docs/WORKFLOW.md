# Workflow — getting real use out of buffer-ctx.nvim day to day

Every subcommand here is documented on its own in
[`docs/FEATURES/`](FEATURES/README.md) and [`docs/commands.md`](commands.md).
This is the different question: once you're mid-edit, which combination of
`:Insert`/`:Copy`/`:Format`/`:Mark` actually gets reached for, and in what
order.

## New Lua file: module line and skeleton agree, because they read the same path

`:Insert annotation module` and `:Insert boilerplate lua-module` both derive
their module name from the buffer's own path under `/lua/` — neither one
ever needs you to type `buffer_ctx.ops.foo` by hand, and the two can never
drift apart the way a hand-typed `---@module` comment and a copy-pasted
skeleton sometimes do. Scaffold a new module in one motion:

```
:Insert boilerplate lua-module    " full module skeleton, already has ---@module
```

or, if the file already has content and only needs the header:

```
:Insert annotation module         " ---@module 'buffer_ctx.ops.foo'
```

`:Copy module lua_ls` is the same derivation again, for when the target for
that line is a *different* buffer — a caller's file, a doc page — rather
than the buffer you're standing in.

## Writing a function: annotate first, dialog for the tedious part

`:Insert annotation param`/`return` one at a time works, but for a function
with several parameters `:Insert annotation function` is the faster path:
it prompts name/type per parameter until you leave one empty, then a return
type, and drops a complete `---@param`/`---@return` block in one motion —
no manual line-by-line assembly. Reach for the single-shot `param`/`return`/
`class`/`field` types instead when you're editing an *existing* annotation
block and only one line needs to change; running the full dialog to fix one
typo is a worse trade than typing that one line by hand.

## Code review and cross-repo references: `location range` beats a hand-built link

Select the lines in visual mode, then `:` (Neovim fills in `'<,'>` for you)
and run the subcommand — `location`'s `range` argument turns the selection
into `path:L1-L2` instead of just the cursor's own line:

```
:'<,'>Copy location range   → "lua/buffer_ctx/ops/filepath.lua:L10-L20"
```

This is genuinely the fast path for a PR comment or a `README` reference to
a specific block — no line-number arithmetic, no re-checking the path
separately. A single-line selection collapses back to plain `path:42`
automatically, so there's no special case to remember for "I only meant one
line."

The README's own suggested pairing is worth calling out here too: use
`:Copy location`/`:Copy module` to drop a `path:line` or `require(...)`
reference *out*, and [gopath.nvim](https://github.com/StefanBartl/gopath.nvim)
to jump straight back to it from anywhere later — the two are built to be
used together, not overlapping.

## Mark: for "gather these lines from across the buffer", not "bookmark for next week"

`:Mark toggle` (`<S-m>`) tags lines as you scroll past them; `:Mark yank`
(`<C-p>`) pulls every tagged line out, sorted by buffer position, joined and
copied as one block. The real use is building a composite from scattered
source — pulling every `TODO` you've eyeballed into one clipboard payload,
or assembling a changelog from lines spread across a diff — not a
persistent bookmark, because mark state is per-buffer and is dropped
outright on `BufDelete`/`BufWipeout` (see
[`FEATURES/MARK.md`](FEATURES/MARK.md)). If you close the buffer, the marks
are gone; do the yank before you do, not after.

One genuine gotcha inherited from the underlying extmark API: on Neovim 0.9
(still the plugin's documented floor), deleting a marked line doesn't
delete its mark — the mark slides onto the line that took its place. On
0.10+ this is exact (the mark is deleted outright with the line). If you're
still on 0.9 and just deleted a marked line, glance at `:Mark yank`'s
output before trusting it blindly.

## Format: clean up pasted content before it becomes a diff

`:Format` operates on whatever's already in the buffer — most useful right
after pasting something from outside (a spreadsheet dump, a Slack message,
a generated Markdown table) rather than on code you wrote yourself:

```
:Format trim                        " strip trailing whitespace pasted content usually carries
:'<,'>Format table                  " realign a Markdown table's columns after editing a cell
:Format squeeze                     " collapse the blank-line runs a paste often leaves behind
```

`column` is the one subcommand that refuses a linewise (`V`) selection
outright — it needs char/blockwise geometry to know what "column" even
means for the selection, so `Vjj:Format column 40` errors instead of
silently aligning against the wrong bounds. Reselect with `v` or `<C-v>` if
that happens.

## `commands = false` and `mark`/`format` toggles: pick your surface area, not just your keymaps

Unlike the 3 core keymaps (which are individually swappable), the command
trees themselves are opt-out wholesale:

| Setting | Effect |
|---|---|
| `commands = false` | No `:Insert`/`:Copy` at all — use `require("buffer_ctx").insert(...)`/`.copy(...)` from Lua instead |
| `keymaps = false` | No `<leader>cnl`/`cnm`/`cnf`, commands unaffected |
| `format = false` | No `:Format` command, no format keymaps to disable (it has none) |
| `mark = false` | No `:Mark`, no `<S-m>`/`<C-p>`, no `BufferCtxMarkCleanup` autocmd registered |

Turning `format`/`mark` off isn't just a keymap decision the way `keymaps =
false` is — it skips registering the subsystem's user command and (for
`mark`) its autocommand entirely, so `:checkhealth buffer_ctx` reports that
section as disabled rather than checking for a command that was never
meant to exist. Reach for this when a config bundles buffer-ctx.nvim
alongside a mark/format plugin that already owns those keys, rather than
fighting over the same bindings.

## `:checkhealth buffer_ctx` after any config change touching keymaps/commands

Because `lib.nvim` is a hard dependency for the command layer specifically
(not just a "nicer if present" one, the way `notify`/`map` are), a broken
or missing `lib.nvim` install fails quietly at first — `:Insert`/`:Copy`/
`:Format`/`:Mark` simply won't exist as commands. `:checkhealth buffer_ctx`
is the fast way to tell "lib.nvim isn't installed" apart from "I typo'd my
own keymap config": it reports each subsystem (core, format, mark)
separately, plus whether the two optional compat commands and the
which-key label actually registered. Run it once after any config change
that touches `keymaps`/`commands`/`format`/`mark`, not only when something
visibly breaks.
