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

## Quickstart

Requires Neovim **0.9+**. See [docs/installation.md](docs/installation.md) for
optional integrations and other package managers.

```lua
-- lazy.nvim
{
  "stefanbartl/buffer-ctx.nvim",
  event = "VeryLazy",
  opts  = {},
}
```

```
:Copy location             " "lua/buffer_ctx/ops/filepath.lua:42"
:Insert timestamp          " 2026-06-22T14:35:00
:Insert boilerplate        " interactive template picker
:Mark toggle               " toggle a mark on the current line
```

`opts = {}` gives you the defaults shown above; see [docs/configuration.md](docs/configuration.md)
to customize keymaps, commands, and templates.

---

## Documentation

- [Installation](docs/installation.md) — requirements, loading strategies, lazy.nvim and packer setup.
- [Configuration](docs/configuration.md) — all available `setup()` options and defaults.
- [Commands](docs/commands.md) — quick reference table and full subcommand reference for `:Insert`, `:Copy`, `:Format`, `:Mark`.
- [Keymaps](docs/keymaps.md) — default keymaps and how to disable or reconfigure them.
- [Lua API](docs/api.md) — the `require("buffer_ctx")` module functions.
- [Bindings cheatsheet](docs/BINDINGS.md) — machine-readable table of every keymap, user command, and autocommand.
- [Tests](docs/TESTS/README.md) — how to run the test suite.

---

## Health check

```
:checkhealth buffer_ctx
```
