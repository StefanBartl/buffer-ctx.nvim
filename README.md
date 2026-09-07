> **Beta stage — active development.** This repository is past its first shape and in
> active use, but the surface is not frozen: breaking changes are still possible. Pin a
> commit or tag if you depend on it.

# buffer-ctx.nvim

```
██████╗ ██╗   ██╗███████╗███████╗███████╗██████╗      ██████╗████████╗██╗  ██╗
██╔══██╗██║   ██║██╔════╝██╔════╝██╔════╝██╔══██╗    ██╔════╝╚══██╔══╝╚██╗██╔╝
██████╔╝██║   ██║█████╗  █████╗  █████╗  ██████╔╝    ██║        ██║    ╚███╔╝
██╔══██╗██║   ██║██╔══╝  ██╔══╝  ██╔══╝  ██╔══██╗    ██║        ██║    ██╔██╗
██████╔╝╚██████╔╝██║     ██║     ███████╗██║  ██║    ╚██████╗   ██║   ██╔╝ ██╗
╚═════╝  ╚═════╝ ╚═╝     ╚═╝     ╚══════╝╚═╝  ╚═╝     ╚═════╝   ╚═╝   ╚═╝  ╚═╝
                                                                   .nvim
```

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%2FLuaJIT-2C2D72?logo=lua&logoColor=white)](https://www.lua.org)
![Status](https://img.shields.io/badge/status-beta-orange)
[![CI](https://github.com/StefanBartl/buffer-ctx.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/StefanBartl/buffer-ctx.nvim/actions/workflows/ci.yml)

Everything the current buffer already knows about itself, as text you can insert
or copy: its path, its Lua module name, the line you are on, a timestamp, a UUID,
an annotation, a boilerplate header.

The buffer holds all of it and hands you none of it. Retyping
`lua/buffer_ctx/ops/filepath.lua:42` into a commit message is a small, frequent,
error-prone job, and it has no reason to be manual.

---

## Table of contents

- [Documentation](#documentation)
- [What it does](#what-it-does)
- [Around it](#around-it)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [What you get with the defaults](#what-you-get-with-the-defaults)
- [Integrations](#integrations)
- [Health check](#health-check)
- [Contributing](#contributing)
- [Feedback](#feedback)
- [License](#license)

---

## Documentation

Start at [docs/README.md](docs/README.md), which says what is where and which
question each page answers.

- [Installation](docs/installation.md) — requirements, loading strategies, every plugin manager.
- [Configuration](docs/configuration.md) — every `setup()` option and its default.
- [Commands](docs/commands.md) — the four command trees, subcommand by subcommand.
- [Keymaps](docs/keymaps.md) — the keys, on one screen, and how to change them.
- [Features](docs/FEATURES/README.md) — one page per area: context, marks, annotations, templates, formatting.
- [Workflow](docs/WORKFLOW.md) — not what each subcommand does, but how they combine into a way of working.
- [Lua API](docs/api.md) — the `require("buffer_ctx")` surface a config or another plugin may call.
- [Bindings cheatsheet](docs/BINDINGS.md) — every keymap, user command and autocommand at a glance.
- [Architecture](docs/architecture.md) — source tree layout and module responsibilities.
- [Health](docs/health.md) — what `:checkhealth buffer_ctx` reports, section by section.
- [Tests](TESTS/README.md) — how to run the spec suite.

`:help buffer-ctx` is the same reference inside the editor.

---

## What it does

Four command trees, split by *what happens to the text* rather than by where it
came from — the same `location` string is worth inserting in one buffer and
copying out of another, and the source has no opinion on which.

| Tree | Does |
| --- | --- |
| **`:Insert {subcmd}`** | Writes text at the cursor: path, module, timestamp, UUID, annotation, boilerplate from a template |
| **`:Copy {subcmd}`** | The same values, to the system clipboard instead of the buffer |
| **`:Format {subcmd}`** | Buffer- and selection-level formatting operations |
| **`:Mark {subcmd}`** | Per-line marks you toggle, clear, and yank as a block — a scratch selection that survives moving around the file |

Marks are the part that is not just a shortcut for typing. They collect lines
from anywhere in a buffer over time and yank them as one clipboard payload, which
is the shape you want when the thing you are quoting is not contiguous.

---

## Around it

> **[gopath.nvim](https://github.com/StefanBartl/gopath.nvim)** — the return
> journey. buffer-ctx produces a `require("foo.bar")` or `path:line` reference;
> gopath takes one written anywhere and jumps to what it names.
>
> **[fileops.nvim](https://github.com/StefanBartl/fileops.nvim)** — acts on the
> file rather than reading from it: create, rename, move, delete. buffer-ctx
> tells you what the buffer *is*, fileops changes it.
>
> [lib.nvim](https://github.com/StefanBartl/lib.nvim) is the one real
> dependency — see [Requirements](#requirements).

---

## Requirements

| | |
| --- | --- |
| Neovim | **0.9+** |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | required — the command layer is built on `lib.nvim.bindings.usercmd.composer` |

Optional, detected at runtime and degrading to nothing when absent:

| | |
| --- | --- |
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) | `:Telescope buffer_ctx boilerplate` — the template picker with a live preview |

---

## Installation

```lua
-- lazy.nvim
{
  "StefanBartl/buffer-ctx.nvim",
  dependencies = { "StefanBartl/lib.nvim" }, -- required
  event = "VeryLazy",
  opts = {},
}
```

`opts = {}` is a complete configuration — it gives you the default keymaps and
command names. Other plugin managers and the load-trigger variants are in
[docs/installation.md](docs/installation.md).

---

## Quickstart

Open any file, put the cursor on a line worth pointing at, and copy the
reference:

```vim
:Copy location
```

The clipboard now holds `lua/buffer_ctx/ops/filepath.lua:42`. The rest follows
the same shape — `:Insert` writes into the buffer, `:Copy` writes to the
clipboard:

```vim
:Insert timestamp          " 2026-06-22T14:35:00 at the cursor
:Insert boilerplate        " interactive template picker
:Mark toggle               " toggle a mark on the current line
:Mark yank                 " all marked lines, as one clipboard payload
```

Verify your setup any time with:

```vim
:checkhealth buffer_ctx
```

---

## What you get with the defaults

`opts = {}` binds these; [docs/configuration.md](docs/configuration.md) turns any
of them off.

| Key | Does |
| --- | --- |
| `<leader>cnl` | Copy `path:line`, relative to the cwd |
| `<leader>cnm` | Copy the Lua module path of the current file |
| `<leader>cnf` | Copy the filepath, relative to the cwd |
| `<S-m>` | Toggle a mark on the current line — `3<S-m>` marks three |
| `<C-p>` | Yank every marked line to the clipboard |

The full set — every key, mode, and the command behind it — is the
[bindings cheatsheet](docs/BINDINGS.md); to bind actions yourself instead, see
[docs/keymaps.md](docs/keymaps.md).

---

## Integrations

### Picker

With [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
installed, `:Telescope buffer_ctx boilerplate` browses the boilerplate templates
with a live preview of what each one inserts. Without it, `:Insert boilerplate`
falls back to `vim.ui.select`, so nothing is lost — see
[docs/installation.md](docs/installation.md).

---

## Health check

```vim
:checkhealth buffer_ctx
```

Reports whether `lib.nvim` resolved, which clipboard provider is in use, and
whether the configured templates exist. Every line it can print is in
[docs/health.md](docs/health.md).

---

## Contributing

Clone the repository and either symlink it or add it to your runtime path.
[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) has the ground rules and the project
layout; [docs/architecture.md](docs/architecture.md) says which module owns what.

Pull requests very welcome.

---

## Feedback

Your feedback is very welcome. Use the
[issue tracker](https://github.com/StefanBartl/buffer-ctx.nvim/issues) to report
bugs, suggest features or ask usage questions; anything more open-ended fits a
[discussion](https://github.com/StefanBartl/buffer-ctx.nvim/discussions).

If you find this plugin useful, a ⭐ on GitHub supports its development.

---

## License

MIT — see [LICENSE](LICENSE).
