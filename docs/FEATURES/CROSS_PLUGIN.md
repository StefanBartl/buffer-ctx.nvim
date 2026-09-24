# Cross-plugin shims

Two `:Insert`/`:Copy` subcommands that reach into a sister plugin instead of
computing their result locally: `mdlink` (markdown.nvim) and
`imagepaste` (images.nvim). Both are soft dependencies — a plain
`pcall(require, ...)`, re-checked on every call, never cached — the same
convention `buffer_ctx.commands`'s own `resolve_kit()` already uses for
`ui.kit`.

## mdlink

- **Tab:** true (shares `filepath`'s mode/format/depth completion)
- **Module:** `ops/markdown_link.lua` (`M.build`)
- **Usercmds:** `:Insert mdlink [mode] [format] [depth]`,
  `:Copy mdlink [mode] [format] [depth]`
- **Tests:** `TESTS/cross_plugin_spec.lua`

Wraps whatever `:Insert`/`:Copy filepath [mode] [format] [depth]` would
produce in a Markdown link (`[title](path)`), reusing `ops/filepath.lua`
directly rather than a second path-resolution implementation.

Delegates to markdown.nvim's own
`markdown.commands.markdown_links.for_paths()` — the function behind
`:Markdown links <path>` — when markdown.nvim is installed. Falls back to
the literal `"[%s](%s)"` format inline otherwise: unlike `imagepaste` below,
this fallback carries no duplication risk, because markdown.nvim's own
`for_paths` hardcodes that exact same format for a single file (see its
`make_link` local function) — there is no configurable link format to drift
out of sync with.

Fits the shared `:Insert`/`:Copy` dispatch table (`buffer_ctx.commands`'s
`DISPATCH`) exactly like every other subcommand: a pure function of its
arguments, routed through the same `sink_text` cursor/clipboard switch.

## imagepaste

- **Tab:** false (its one positional arg is a free-form file name, not a
  fixed set)
- **Module:** `ops/imagepaste.lua` (`M.paste`)
- **Usercmds:** `:Insert imagepaste [name] [path=relative|absolute|repos|<prefix>]`
- **Tests:** `TESTS/cross_plugin_spec.lua`

Delegates to images.nvim's own clipboard-paste feature
(`require("images").paste(name, nil, path_mode)`) — the exact `{name}`/
`path=...` grammar `:Image paste` itself accepts.

**`:Insert`-only — there is no `:Copy imagepaste`.** Every other subcommand
here is a pure function: compute a string, then either insert it at the
cursor or copy it to the clipboard (`buffer_ctx.commands`'s `sink_text`).
images.nvim's `paste.run` doesn't fit that shape — it reads the OS clipboard
*asynchronously* and inserts the resulting Markdown link directly into the
buffer itself (see `images/paste.lua`'s `insert_link`), the same "side
effect on an external resource, not a value returned to a sink" shape
[`ops/reveal.lua`](REVEAL.md) already has for `reveal_in_fm`/`open.nvim`.
There is no "give me the link text instead of inserting it" mode in
images.nvim's public API to route through a clipboard sink, and
reimplementing its clipboard-read pipeline here (`paste.lua`'s per-platform
Windows/macOS/Linux clipboard-to-file dispatch) just to intercept that one
step would duplicate logic that already exists once, there, on purpose —
exactly the duplication `ops/reveal.lua` itself already declines for
`reveal_in_fm`.

Because of that, `imagepaste` is wired outside the shared `DISPATCH` table:
a route appended only to the `:Insert` verb's route list in
`commands.lua`'s `M.register()`, not part of `build_routes(sink)`'s loop
over `SUBCMDS`. `:Copy imagepaste` therefore doesn't merely "do nothing" —
it doesn't exist as a subcommand at all (attempting it errors "unknown
subcommand", the same as any other typo).

No local fallback when images.nvim is absent (unlike `mdlink` above):
the clipboard-read pipeline is genuinely nontrivial and platform-specific,
so `imagepaste` simply reports the missing dependency rather than
half-reimplementing it.

## Why not a generic "provider registry"

Both shims follow the exact same shape — `pcall(require, "<sister plugin>")`,
call its public API on success, degrade (or error) on failure — and it would
be easy to imagine a `lua/buffer_ctx/providers/init.lua` with a
`register(name, spec)`/discovery layer generalizing that pattern. That was
deliberately not built here.

With exactly two sister plugins involved, and each shim needing genuinely
different handling on the failure path (`mdlink` degrades gracefully
inline; `imagepaste` has nothing sensible to degrade *to*) and a different
place in the command tree (`mdlink` is a normal `DISPATCH` entry under
both `:Insert`/`:Copy`; `imagepaste` is an `:Insert`-only route bypassing
`DISPATCH` entirely), a registry abstraction would need to accommodate both
shapes from day one — for two call sites, each already only a few lines long
next to the pattern `resolve_kit()` already established in this same file.
That is the textbook case for the project's own standing guidance: three (or
here, two) similar lines are better than a premature abstraction built
before a third, real, differently-shaped use case shows up to justify it. If
a third cross-plugin shim of this kind is ever added and turns out to share
enough shape with these two, extracting a shared helper then — with three
real examples to generalize from instead of two imagined ones — will be a
far better-informed decision than guessing at the right shape now.
