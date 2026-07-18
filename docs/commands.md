# Commands

Four command trees:

- **`:Insert {subcmd} [args…]`** — writes text at cursor position
- **`:Copy   {subcmd} [args…]`** — copies text to the system clipboard
- **`:Format {subcmd} [args…]`** — buffer/selection formatting operations
- **`:Mark   {subcmd}`**         — toggle per-line marks and yank them to clipboard

## Quick reference

| Subcommand | Args | Result |
|---|---|---|
| `filepath` | `[cwd\|abs\|nvim\|nvim_module] [lua\|unix\|win\|system] [0-3]` | Path of current buffer |
| `filename` | `[noext]` | Filename (with/without extension) |
| `module` | `[require\|lua_ls\|js\|c\|generic]` | Lua `require(…)` or `---@module` |
| `location` | `[cwd\|abs\|lua] [range]` | `path:line`, or `path:L1-L2` with `range` |
| `timestamp` | `[format] [--utc]` | Current timestamp |
| `date` | — | Shorthand for `timestamp iso-date` |
| `uuid` | `[standard\|compact\|upper\|braced]` | UUID v4 |
| `annotation` | `module\|class\|field\|param\|return\|function\|alias\|overload\|diagnostic\|deprecated` | LuaLS annotation line(s) |
| `boilerplate` | `[template] [name]` | Multi-line code template (no arg → picker) |
| `snippet` | `[name]` | VSCode-format snippet (no arg → picker) |
| `env` | `{VAR}` | Value of environment variable |
| `git` | `[hash\|short\|branch\|tag]` | Git revision info for the buffer's repo |
| `linecount` | — | Line count of the current buffer |
| `bufnr` | — | Handle of the current buffer |

### Mark subcommands

| Subcommand | Action |
|---|---|
| `toggle` | Toggle mark on current line (`●` in sign column or as extmark) |
| `yank` | Yank all marked lines (buffer order) to system clipboard |

Compat commands: `:MarkLineToggle` → `:Mark toggle`, `:MarkLinesYank` → `:Mark yank`

### Format subcommands

| Subcommand | Args | Action |
|---|---|---|
| `column <N> [fill]` | target column, fill char | Align visual selection to column |
| `table [ALIGN] [opts]` | `header=`, `cell=`, `skip=`, `scope=` | Format Markdown table(s) |
| `textwidth <N\|max>` | number or `max` (window width) | Set `textwidth` and reflow text |
| `filter [--remove] <pat>` | pattern(s) | Keep or remove matching lines |
| `enum [STYLE] [opts]` | `decimal`/`alpha`/`roman`, `sep=`, `start=`, `inline=` | Enumerate visual selection tokens |
| `trim` | — | Remove trailing whitespace |
| `sort [-r] [-i] [-n]` | flags | Sort lines |
| `unique [-i]` | flag | Remove duplicate lines |
| `case <mode>` | `upper`/`lower`/`title`/`sentence` | Change case |
| `indent [--spaces\|--tabs] [N]` | flags, width | Fix indentation |
| `clear` | — | Clear buffer |

## Subcommand reference

### `filepath [mode] [format] [depth]`

Copy or insert the current buffer's path.

| Arg | Values | Default |
|---|---|---|
| mode | `cwd`/`relative`/`rel`, `abs`/`absolute`, `nvim` | `cwd` |
| format | `unix`, `lua`, `win`, `system` | `unix` |
| depth | `0`–`3` (last N+1 segments) | full path |

```
:Copy filepath                 → "lua/buffer_ctx/ops/filepath.lua"
:Copy filepath abs             → "/home/user/…/filepath.lua"
:Copy filepath lua             → "buffer_ctx.ops.filepath"
:Copy filepath 1               → "filepath.lua"
:Copy filepath nvim            → relative to stdpath("config")
```

### `filename [noext]`

```
:Insert filename               → "filepath.lua"
:Insert filename noext         → "filepath"
```

### `module [style]`

Derive the Lua module path from the `/lua/` segment in the buffer's path.

| Style | Output |
|---|---|
| `require` (default) | `require("foo.bar")` |
| `lua_ls` / `luals` | `---@module 'foo.bar'` |
| `js` | `import "foo/bar"` |
| `c` | `#include "foo/bar.h"` |
| `generic` | `foo.bar` |

```
:Copy module               → require("buffer_ctx.ops.filepath")
:Copy module lua_ls        → ---@module 'buffer_ctx.ops.filepath'
```

### `location [mode] [range]`

Current buffer path + cursor line number.

```
:Copy location             → "lua/buffer_ctx/ops/filepath.lua:42"
:Copy location abs         → "/home/user/…/filepath.lua:42"
:Copy location lua         → "buffer_ctx.ops.filepath:42"
```

With `range`, the line span is emitted instead — handy for code-review
comments and GitHub links. Select the lines in visual mode and press `:`
(Neovim inserts `'<,'>` for you), or pass a range yourself:

```
:'<,'>Copy location range  → "lua/buffer_ctx/ops/filepath.lua:L10-L20"
:10,20Copy location range  → "lua/buffer_ctx/ops/filepath.lua:L10-L20"
:Copy location range       → falls back to the last visual selection
```

A single-line range has no span to express, so it collapses to `path:42`.

### `timestamp [format] [--utc]`

| Format | Example output |
|---|---|
| `iso` (default) | `2026-06-22T14:35:00` |
| `iso-date` | `2026-06-22` |
| `iso-time` | `14:35:00` |
| `unix` | `1750600500` |
| `human` | `June 22, 2026 14:35` |
| `short` | `22.06.2026` |
| `log` | `2026-06-22 14:35:00` |
| `filename` | `20260622_143500` |

```
:Insert timestamp               → 2026-06-22T14:35:00
:Insert timestamp short --utc   → 22.06.2026 (UTC)
```

Set `timestamp = { utc = true }` in the config (see [Configuration](configuration.md))
to make every timestamp UTC without passing `--utc` each time.

### `date`

Shorthand for `timestamp iso-date`.

```
:Insert date               → 2026-06-22
```

### `uuid [format]`

| Format | Example |
|---|---|
| `standard` (default) | `550e8400-e29b-41d4-a716-446655440000` |
| `compact` | `550e8400e29b41d4a716446655440000` |
| `upper` | `550E8400-E29B-41D4-A716-446655440000` |
| `braced` | `{550e8400-e29b-41d4-a716-446655440000}` |

### `annotation {type} [args…]`

| Type | Args | Output |
|---|---|---|
| `module` | — | `---@module 'foo.bar'` (from buffer path) |
| `class` | `[name]` | `---@class MyClass` |
| `field` | `[name] [type]` | `---@field name type` |
| `param` | `[name] [type]` | `---@param name type` |
| `return` | `[type]` | `---@return type` |
| `alias` | `[name] [type]` | `---@alias Name string` |
| `overload` | `[signature]` | `---@overload fun(a: string): boolean` |
| `diagnostic` | `[code]` | `---@diagnostic disable-next-line: code` |
| `deprecated` | `[reason]` | `---@deprecated Reason` |
| `function` | — | interactive dialog → multi-line block |

Args not supplied via command are prompted interactively with `vim.fn.input`.

```
:Insert annotation module                        → ---@module 'buffer_ctx.ops.module'
:Insert annotation class MyClass                 → ---@class MyClass
:Insert annotation overload fun(a: string): bool → ---@overload fun(a: string): bool
:Insert annotation diagnostic undefined-field    → ---@diagnostic disable-next-line: undefined-field
:Insert annotation deprecated use M.new instead  → ---@deprecated use M.new instead
:Insert annotation function                      → (guided dialog)
```

`overload` takes the signature as free text (it may contain spaces) and wraps
it in `fun(…)` if you leave that off. `deprecated` likewise keeps the whole
reason, not just the first word.

To get a multi-line annotation onto the clipboard as one `\n`-joined string,
use `:Copy annotation function` — the copy sink joins the generated lines.

### `boilerplate [template] [name]`

Called without a template name, this opens a `vim.ui.select` picker of the
available keys — no need to rely on tab completion.

Templates:

| Key | Description |
|---|---|
| `lua-module` | Lua module skeleton with `---@module` + `setup()` |
| `lua-class` | OOP class with `new()` constructor |
| `lua-function` | Annotated function stub |
| `nvim-autocmd` | `nvim_create_autocmd` block |
| `nvim-keymap` | `vim.keymap.set` stub |
| `guard-clause` | Guard clause pattern (interactive) |
| `html-figure` | `<figure>` with img + caption |
| `html-code` | Code listing `<figure>` |
| `html-quote` | Blockquote `<figure>` |
| `html-formula-table` | Formula reference table |
| `html-aside` | `<aside>` block |
| `html-pagination` | Pagination `<nav>` |
| `html-accordion` | `<details>` accordion |
| `html-table` | `<table>` with thead + 3×3 body |
| `html-section` | `<section>` with h2 + p |
| `lua-test` | busted test stub (`describe`/`it`/`assert.are.equal`) |
| `lua-enum` | Enum table + `---@alias` block |
| `md-frontmatter` | YAML frontmatter for Markdown |

```
:Insert boilerplate                       → interactive template picker
:Insert boilerplate lua-module            → module skeleton (name from buffer path)
:Insert boilerplate lua-class MyService   → class skeleton named MyService
:Insert boilerplate nvim-autocmd MyGroup  → autocmd with group name
:Copy   boilerplate html-figure intro     → copies <figure id="…"> to clipboard
```

With telescope.nvim installed, `:Telescope buffer_ctx boilerplate` offers the
same list with a live preview of the lines each template would generate:

```lua
require("telescope").load_extension("buffer_ctx")
```

### `snippet [name]`

Loads snippets in the VSCode format from the files listed in
`snippets = { paths = {…} }` (see [Configuration](configuration.md)):

```json
{
  "For Loop": {
    "prefix": "forl",
    "body": ["for ${1:i} = 1, ${2:10} do", "\t$0", "end"],
    "description": "numeric for loop"
  }
}
```

A snippet resolves by its key (`For Loop`) or its prefix (`forl`). Called
without a name, it opens a picker.

```
:Insert snippet            → interactive snippet picker
:Insert snippet forl       → for i = 1, 10 do … end
```

Placeholders are flattened, not expanded: `${1:i}` becomes `i`, `${1|a,b|}`
becomes `a`, and bare tabstops (`$0`, `$1`) are dropped. buffer-ctx inserts
plain text — if you need real tabstop navigation, use a snippet engine.

### `env {VAR}`

Tab completion lists the environment variables currently set.

```
:Copy env GOPATH          → copies value of $GOPATH
:Insert env HOME          → inserts value of $HOME at cursor
```

### `git [mode]`

Git revision info for the repository the current buffer lives in (queried in
the buffer's own directory, so it stays correct after `:cd`).

| Mode | Output |
|---|---|
| `short` (default) | `a577942` |
| `hash` | `a577942dedbcb4e8a4e9ffb3529be12b27b58736` |
| `branch` | `main` |
| `tag` | nearest tag, else abbreviated hash (`git describe --tags --always`) |

```
:Insert git               → a577942
:Copy   git branch        → main
```

Requires `git` in `PATH`. On a detached HEAD, `branch` reports an error
rather than returning the literal string `HEAD`.

### `linecount` / `bufnr`

```
:Insert linecount         → 348   (lines in the current buffer)
:Insert bufnr             → 3     (current buffer handle)
```
