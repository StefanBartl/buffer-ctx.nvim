# Installation

## Requirements

- Neovim **0.9+**
- [lib.nvim](https://github.com/StefanBartl/lib.nvim) — **required**: the `:Insert`/`:Copy`/`:Format`/`:Mark` command layer is built on `lib.nvim.bindings.usercmd.composer`. `notify`/`map` remain a soft dependency on top of that (nicer formatting when installed, falls back to plain `vim.notify`/`vim.keymap.set` otherwise)
- *(optional)* [which-key.nvim](https://github.com/folke/which-key.nvim) — labels the `<leader>cn` keymap group when installed
- *(optional)* [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) — enables `:Telescope buffer_ctx boilerplate`, a picker over the boilerplate templates with a live preview of what each one inserts. Without it, `:Insert boilerplate` falls back to `vim.ui.select`, so nothing is lost.
- *(optional)* `git` in `PATH` — only for the `git` subcommand
- *(optional)* [ui.nvim](https://github.com/StefanBartl/ui.nvim) — `ui.kit`'s `select`/`input`/`form` back the snippet/boilerplate picker prompts and the interactive column-align/guard-clause templates; lazily required, so nothing loads it until one of those runs
- *(optional)* [open.nvim](https://github.com/StefanBartl/open.nvim) — `:OpenInBrowser` delegates to its `browser` handler when installed; without it, falls back to `vim.ui.open` (Neovim 0.10+), so nothing is lost
- *(optional)* [markdown.nvim](https://github.com/StefanBartl/markdown.nvim) — `:Insert`/`:Copy mdlink` delegates to its own link builder when installed; without it, falls back to a literal `"[title](path)"`, so nothing is lost
- *(optional)* [images.nvim](https://github.com/StefanBartl/images.nvim) — `:Insert imagepaste` delegates to its `paste` feature. **No fallback** — this one subcommand fails without images.nvim installed; the rest of `:Insert`/`:Copy` is unaffected

## Choosing a loading strategy

| Variant | Startup impact | Commands available | When to use |
|---|---|---|---|
| **`cmd` (lazy)** | Minimal | ✓ (loads on first use) | Large config, many plugins |
| **`event = "VeryLazy"`** | Minimal (after startup) | ✓ | **Recommended** — default below |
| **`lazy = false`** | Immediate | ✓ | Want instant command availability |

## lazy.nvim

*Recommended (load shortly after startup):*
```lua
{
  "stefanbartl/buffer-ctx.nvim",
  dependencies = { "stefanbartl/lib.nvim" },
  event = "VeryLazy",
  opts  = {},
}
```

*Lazy-loaded on command use:*
```lua
{
  "stefanbartl/buffer-ctx.nvim",
  dependencies = { "stefanbartl/lib.nvim" },
  cmd  = { "Insert", "Copy", "Format", "Mark", "RevealInFm", "OpenInBrowser" },
  opts = {},
}
```

*Load at startup (eager):*
```lua
{
  "stefanbartl/buffer-ctx.nvim",
  dependencies = { "stefanbartl/lib.nvim" },
  lazy = false,
  opts = {},
}
```

## packer

*Default setup:*
```lua
use {
  "stefanbartl/buffer-ctx.nvim",
  requires = { "stefanbartl/lib.nvim" },
  config = function()
    require("buffer_ctx").setup()
  end,
}
```

*With immediate load (packer equivalent of `lazy = false`):*
```lua
use {
  "stefanbartl/buffer-ctx.nvim",
  requires = { "stefanbartl/lib.nvim" },
  module_pattern = "buffer_ctx", -- eager
  config = function()
    require("buffer_ctx").setup()
  end,
}
```

See [Configuration](configuration.md) for all available `setup()` options.
