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

---

## Documentation

Start at [docs/README.md](docs/README.md) — what's where, and which question
each page answers.

### The Basics

- [Requirements](docs/installation.md#requirements) — Neovim version, required and optional plugins.
- [Installation](docs/installation.md) — plugin managers and load-trigger variants.
- [Quickstart](docs/quickstart.md) — the first commands to run after installing.

### Using it

- [Configuration](docs/configuration.md) — every `setup()` option and its default.
- [Commands](docs/commands.md) — the four command trees, subcommand by subcommand.
- [Keymaps](docs/keymaps.md) — the keys, on one screen, and how to change them.
- [Bindings cheatsheet](docs/BINDINGS.md) — every keymap, user command and autocommand at a glance.
- [Features](docs/FEATURES/README.md) — one page per area: context, marks, annotations, templates, formatting.
- [Workflow](docs/WORKFLOW.md) — not what each subcommand does, but how they combine into a way of working.
- [Lua API](docs/api.md) — the `require("buffer_ctx")` surface a config or another plugin may call.

### The Rest

- [Around it](docs/around-it.md) — how this plugin's scope differs from its siblings in the collection.
- [Architecture](docs/architecture.md) — source tree layout and module responsibilities.
- [Health check](docs/health.md) — what `:checkhealth buffer_ctx` reports, section by section.
- [Contributing](docs/CONTRIBUTING.md) — ground rules and project layout.
- [Feedback](https://github.com/StefanBartl/buffer-ctx.nvim/issues) — bugs, features, questions.
- [Tests](TESTS/README.md) — how to run the spec suite.

`:help buffer-ctx` is the same reference inside the editor.

---

## License

MIT — see [LICENSE](LICENSE).
