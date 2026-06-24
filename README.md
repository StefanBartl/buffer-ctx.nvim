# buffer-ctx.nvim

Buffer context for Neovim — insert or copy path, module, timestamp, UUID,
annotations, boilerplate, and more from the current buffer.

Four command trees:

- **`:Insert {subcmd} [args…]`** — writes text at cursor position
- **`:Copy   {subcmd} [args…]`** — copies text to the system clipboard
- **`:Format {subcmd} [args…]`** — buffer/selection formatting operations
- **`:Mark   {subcmd}`**         — toggle per-line marks and yank them to clipboard

---

## Quick reference

| Subcommand | Args | Result |
|---|---|---|
| `filepath` | `[cwd\|abs\|nvim] [lua\|unix\|win\|system] [0-3]` | Path of current buffer |
| `filename` | `[noext]` | Filename (with/without extension) |
| `module` | `[require\|lua_ls\|js\|c\|generic]` | Lua `require(…)` or `---@module` |
| `location` | `[cwd\|abs\|lua]` | `path:line` of current cursor |
| `timestamp` | `[format] [--utc]` | Current timestamp |
| `uuid` | `[standard\|compact\|upper\|braced]` | UUID v4 |
| `annotation` | `module\|class\|field\|param\|return\|function\|alias` | LuaLS annotation line(s) |
| `boilerplate` | `{template} [name]` | Multi-line code template |
| `env` | `{VAR}` | Value of environment variable |

---

## Mark subcommands

| Subcommand | Action |
|---|---|
| `toggle` | Toggle mark on current line (`●` in sign column or as extmark) |
| `yank` | Yank all marked lines (buffer order) to system clipboard |

Compat commands: `:MarkLineToggle` → `:Mark toggle`, `:MarkLinesYank` → `:Mark yank`

---

## Format subcommands

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

---

## Requirements

- Neovim 0.9+
- [`lib.nvim`](https://github.com/StefanBartl/lib.nvim) (notify wrapper)

---

## Installation

```lua
-- lazy.nvim (local checkout)
{
  dir   = vim.env.REPOS_DIR .. "/buffer-ctx.nvim",
  event = "VeryLazy",
  opts  = {},
}
```

---

## Configuration

```lua
require("buffer_ctx").setup({
  commands = true,           -- register :Insert and :Copy
  keymaps = {
    location_copy = "<leader>cnl",   -- copy path:line
    module_copy   = "<leader>cnm",   -- copy Lua module path
    filepath_copy = "<leader>cnf",   -- copy relative filepath
  },
  -- keymaps = false  to disable all keymaps
  format = {
    enable  = true,          -- register :Format (default true)
    command = "Format",      -- command name
  },
  -- format = false   to disable :Format entirely
  mark = {
    enable  = true,          -- register :Mark (default true)
    command = "Mark",        -- command name
    keymaps = {
      toggle = "<S-m>",      -- toggle mark on current line
      yank   = "<C-p>",      -- yank all marked lines
    },
  },
  -- mark = false   to disable :Mark entirely
})
```

---

## Subcommand reference

### `filepath [mode] [format] [depth]`

Copy or insert the current buffer's path.

| Arg | Values | Default |
|---|---|---|
| mode | `cwd`, `abs`, `nvim` | `cwd` |
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

### `location [mode]`

Current buffer path + cursor line number.

```
:Copy location             → "lua/buffer_ctx/ops/filepath.lua:42"
:Copy location abs         → "/home/user/…/filepath.lua:42"
:Copy location lua         → "buffer_ctx.ops.filepath:42"
```

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
| `function` | — | interactive dialog → multi-line block |

Args not supplied via command are prompted interactively with `vim.fn.input`.

```
:Insert annotation module          → ---@module 'buffer_ctx.ops.module'
:Insert annotation class MyClass   → ---@class MyClass
:Insert annotation function        → (guided dialog)
```

### `boilerplate {template} [name]`

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

```
:Insert boilerplate lua-module            → module skeleton (name from buffer path)
:Insert boilerplate lua-class MyService   → class skeleton named MyService
:Insert boilerplate nvim-autocmd MyGroup  → autocmd with group name
:Copy   boilerplate html-figure intro     → copies <figure id="…"> to clipboard
```

### `env {VAR}`

```
:Copy env GOPATH          → copies value of $GOPATH
:Insert env HOME          → inserts value of $HOME at cursor
```

---

## Keymaps

| Key | Action |
|---|---|
| `<leader>cnl` | Copy `path:line` (cwd-relative) |
| `<leader>cnm` | Copy Lua module path |
| `<leader>cnf` | Copy filepath (cwd-relative) |

All keymaps are configurable. Set `keymaps = false` to disable all.

---

## Lua API

```lua
local ctx = require("buffer_ctx")

ctx.setup(opts)           -- configure + activate (idempotent)
ctx.insert(subcmd, args)  -- same as :Insert {subcmd} [args…]
ctx.copy(subcmd, args)    -- same as :Copy {subcmd} [args…]
```

---

## Architecture

```
lua/buffer_ctx/
  init.lua             setup() + public API
  config.lua           defaults + active config store
  @types.lua           LuaLS annotations
  commands.lua         :Insert / :Copy dispatch + tab completion
  keymaps.lua          vim.keymap.set registrations
  health.lua           :checkhealth buffer_ctx
  format/
    init.lua           :Format command + subcommand registry
    column_align.lua   Column-alignment logic
    table_fmt.lua      Markdown table formatter
    text_width.lua     Text reflow (word-wrap)
    filter_lines.lua   Line filter (keep/remove)
    enum_lines.lua     Token enumeration for visual selection
    misc.lua           trim, sort, unique, case, indent, clear
  mark/
    init.lua           :Mark command + toggle/yank logic
  util/
    notify.lua         "[buffer-ctx] " prefixed vim.notify wrapper
    cursor.lua         insert_text / insert_lines at cursor
    clip.lua           setreg("+", …) + notify
    path.lua           get_module_path, relative_to_cwd, normalize_sep
  ops/
    filepath.lua       path formatting
    module.lua         Lua module path → statement
    timestamp.lua      timestamp generation
    uuid.lua           UUID v4
    annotation.lua     LuaLS annotation lines
    location.lua       path:line
    env.lua            env var lookup
    boilerplate/
      init.lua         template registry + dispatch
      templates/
        lua.lua        Lua code templates
        nvim.lua       Neovim-specific templates
        html.lua       HTML snippet templates
        guard.lua      Guard clause templates
        utils.lua      Shared prompt helpers
plugin/
  buffer_ctx.lua       load guard
```

---

## Health check

```
:checkhealth buffer_ctx
```

---

## License

MIT
