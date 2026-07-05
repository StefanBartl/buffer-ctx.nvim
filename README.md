```
██████╗ ██╗   ██╗███████╗███████╗███████╗██████╗      ██████╗████████╗██╗  ██╗
██╔══██╗██║   ██║██╔════╝██╔════╝██╔════╝██╔══██╗    ██╔════╝╚══██╔══╝╚██╗██╔╝
██████╔╝██║   ██║█████╗  █████╗  █████╗  ██████╔╝    ██║        ██║    ╚███╔╝
██╔══██╗██║   ██║██╔══╝  ██╔══╝  ██╔══╝  ██╔══██╗    ██║        ██║    ██╔██╗
██████╔╝╚██████╔╝██║     ██║     ███████╗██║  ██║    ╚██████╗   ██║   ██╔╝ ██╗
╚═════╝  ╚═════╝ ╚═╝     ╚═╝     ╚══════╝╚═╝  ╚═╝     ╚═════╝   ╚═╝   ╚═╝  ╚═╝
                                                                   .nvim
```

[![Neovim](https://img.shields.io/badge/Neovim-0.9+-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Made%20with-Lua-2C2D72?logo=lua&logoColor=white)](https://www.lua.org)

> 💡 Pairs well with [gopath.nvim](https://github.com/StefanBartl/gopath.nvim):
> use buffer-ctx to generate a `require("foo.bar")` / `path:line` reference,
> and gopath to jump straight back to it from anywhere.

Buffer context for Neovim — insert or copy path, module, timestamp, UUID,
annotations, boilerplate, and more from the current buffer.

Four command trees:

- **`:Insert {subcmd} [args…]`** — writes text at cursor position
- **`:Copy   {subcmd} [args…]`** — copies text to the system clipboard
- **`:Format {subcmd} [args…]`** — buffer/selection formatting operations
- **`:Mark   {subcmd}`**         — toggle per-line marks and yank them to clipboard

---

## Table of contents

- [Quick reference](#quick-reference)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Subcommand reference](#subcommand-reference)
- [Keymaps](#keymaps)
- [Lua API](#lua-api)
- [Health check](#health-check)
- [Tests](#tests)

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

---

## Requirements

- Neovim **0.9+**
- *(optional)* [lib.nvim](https://github.com/StefanBartl/lib.nvim) — used for `notify` when installed, falls back to plain `vim.notify` otherwise
- *(optional)* [which-key.nvim](https://github.com/folke/which-key.nvim) — labels the `<leader>cn` keymap group when installed

---

## Installation

**When to use which:**

| Variant | Startup impact | Commands available | When to use |
|---|---|---|---|
| **`cmd` (lazy)** | Minimal | ✓ (loads on first use) | Large config, many plugins |
| **`event = "VeryLazy"`** | Minimal (after startup) | ✓ | **Recommended** — default below |
| **`lazy = false`** | Immediate | ✓ | Want instant command availability |

### lazy.nvim

*Recommended (load shortly after startup):*
```lua
{
  "stefanbartl/buffer-ctx.nvim",
  event = "VeryLazy",
  opts  = {},
}
```

*Lazy-loaded on command use:*
```lua
{
  "stefanbartl/buffer-ctx.nvim",
  cmd  = { "Insert", "Copy", "Format", "Mark" },
  opts = {},
}
```

*Load at startup (eager):*
```lua
{
  "stefanbartl/buffer-ctx.nvim",
  lazy = false,
  opts = {},
}
```

### packer

*Default setup:*
```lua
use {
  "stefanbartl/buffer-ctx.nvim",
  config = function()
    require("buffer_ctx").setup()
  end,
}
```

*With immediate load (packer equivalent of `lazy = false`):*
```lua
use {
  "stefanbartl/buffer-ctx.nvim",
  module_pattern = "buffer_ctx", -- eager
  config = function()
    require("buffer_ctx").setup()
  end,
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
  which_key = true,          -- label <leader>cn group when which-key is installed
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
    sign = {
      text = "●",            -- sign column / extmark glyph
      hl   = "ErrorMsg",     -- highlight group
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
| `<S-m>` | `:Mark toggle` (toggle mark on current line) |
| `<C-p>` | `:Mark yank` (yank all marked lines to clipboard) |

All keymaps are configurable. Set `keymaps = false` to disable the core 3;
set `mark = { keymaps = false }` to disable the mark keymaps.

When [which-key.nvim](https://github.com/folke/which-key.nvim) is installed,
the `<leader>cn` prefix is automatically labeled "buffer-ctx: copy context".
Set `which_key = false` to disable this.

---

## Lua API

```lua
local ctx = require("buffer_ctx")

ctx.setup(opts)           -- configure + activate (idempotent)
ctx.insert(subcmd, args)  -- same as :Insert {subcmd} [args…]
ctx.copy(subcmd, args)    -- same as :Copy {subcmd} [args…]
```

---

## Health check

```
:checkhealth buffer_ctx
```

---

## Tests

```sh
nvim --headless -u NONE -c "set rtp+=." -c "luafile docs/TESTS/run.lua" -c "qa!"
```

See [docs/TESTS/README.md](docs/TESTS/README.md).
