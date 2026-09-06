# Context

The `:Insert`/`:Copy` subcommands that describe *where you are*: the
current buffer's path, its Lua module name, a cursor location, a
timestamp, a UUID, an environment variable, the git revision, or basic
buffer info. Every subcommand here is dispatched through the same table
and only differs in where the result goes — cursor (`:Insert`) or system
clipboard (`:Copy`).

## Filepath

Copies or inserts the current buffer's path in a chosen mode, format, and
depth: cwd-relative (default), absolute, or `stdpath("config")`-relative,
rendered as a unix/lua/win/system path, optionally truncated to the last
N path segments.

- **Module:** `ops/filepath.lua` (`get_path`, `parse_args`)
- **Keymaps:** [`<leader>cnf`](../BINDINGS.md#keymaps)
- **Usercmds:** `:Insert filepath`, `:Copy filepath`, plus the compat
  aliases `:CopyFilepathAbsolute` / `:CopyFilepathRelative`

```
:Copy filepath                 → "lua/buffer_ctx/ops/filepath.lua"
:Copy filepath abs             → "/home/user/…/filepath.lua"
:Copy filepath lua             → "buffer_ctx.ops.filepath"
:Copy filepath 1               → "filepath.lua"
```

## Filename

Just the buffer's filename, with or without its extension — the
narrower sibling of `filepath` for when the directory doesn't matter.

- **Module:** `ops/filepath.lua` (`get_filename`)
- **Usercmds:** `:Insert filename [noext]`, `:Copy filename [noext]`

## Module path

Derives a Lua module reference from the `/lua/` segment of the buffer's
path, in one of five output styles — `require(...)`, a LuaLS `---@module`
line, a JS-style import, a C `#include`, or the bare dotted path.

- **Module:** `ops/module.lua` (`get_statement`, `parse_args`)
- **Keymaps:** [`<leader>cnm`](../BINDINGS.md#keymaps)
- **Usercmds:** `:Insert module [style]`, `:Copy module [style]`; also
  reachable as `:Copy filepath nvim_module`

```
:Copy module               → require("buffer_ctx.ops.filepath")
:Copy module lua_ls        → ---@module 'buffer_ctx.ops.filepath'
```

## Location

The buffer's path plus the cursor's line number (`path:line`), or, with a
command range and the `range` argument, a line span (`path:L1-L2`) — handy
for code-review comments and GitHub permalinks. A single-line range
collapses back to `path:line` since there's no span to express.

- **Module:** `ops/location.lua` (`get`, `get_range`, `parse_args`)
- **Keymaps:** [`<leader>cnl`](../BINDINGS.md#keymaps)
- **Usercmds:** `:Insert location [mode] [range]`, `:Copy location [mode] [range]`

```
:Copy location              → "lua/buffer_ctx/ops/filepath.lua:42"
:'<,'>Copy location range   → "lua/buffer_ctx/ops/filepath.lua:L10-L20"
```

## Timestamp & date

Formats the current time in one of 13 named styles (ISO variants, unix
epoch, human, short, log, filename-safe, weekday, long, 12-hour, RFC 2822,
date- and time-only). `date` is a shorthand for `timestamp iso-date`. A per-buffer `--utc` flag or the sticky
`timestamp.utc` config option both force UTC; the flag always wins over
config.

- **Module:** `ops/timestamp.lua` (`format_timestamp`, `parse_args`)
- **Config:** `opts.timestamp.utc` (default `false`)
- **Usercmds:** `:Insert timestamp [format] [--utc]`, `:Insert date`, and
  their `:Copy` equivalents

## UUID

Generates a random UUID v4 in one of four renderings: standard, compact
(no dashes), uppercase, or brace-wrapped.

- **Module:** `ops/uuid.lua` (`get`, `parse_args`)
- **Usercmds:** `:Insert uuid [format]`, `:Copy uuid [format]`

## Environment variable

Looks up the value of an environment variable, with tab completion over
the variables currently set in the process environment.

- **Module:** `ops/env.lua` (`get`, `list_names`)
- **Usercmds:** `:Insert env {VAR}`, `:Copy env {VAR}`

## Git revision info

Short hash, full hash, current branch, or nearest tag for the git
repository the current buffer lives in — queried in the buffer's own
directory (not the current working directory), so it stays correct after
`:cd`. On a detached HEAD, `branch` reports an error instead of the
literal string `HEAD`.

- **Module:** `ops/git.lua` (`get`, `parse_args`)
- **Usercmds:** `:Insert git [mode]`, `:Copy git [mode]`

Requires `git` in `PATH`.

## Buffer info

Two small, argument-free lookups: `linecount` (line count of the current
buffer) and `bufnr` (the current buffer's handle). Grouped together
because both are one-shot facts about the buffer object itself, not
about its content or location.

- **Module:** `ops/bufinfo.lua` (`get_linecount`, `get_bufnr`)
- **Usercmds:** `:Insert linecount`, `:Insert bufnr`, and their `:Copy`
  equivalents
