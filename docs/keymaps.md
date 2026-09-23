# Keymaps

| Key | Action |
|---|---|
| `<leader>cnl` | Copy `path:line` (cwd-relative) |
| `<leader>cnm` | Copy Lua module path |
| `<leader>cnf` | Copy filepath (cwd-relative) |
| `<S-m>` | `:Mark toggle` (toggle mark on current line; `3<S-m>` marks three lines) |
| `<C-p>` | `:Mark yank` (yank all marked lines to clipboard) |
| `<leader>of` | `:RevealInFm` (reveal current buffer in the system file manager) |
| `<leader>ob` | `:OpenInBrowser` (open current buffer in the browser) |

All keymaps are configurable. Set `keymaps = false` to disable the core 3;
set `mark = { keymaps = false }` to disable the mark keymaps; set
`reveal = { keymaps = false }` to disable the reveal keymaps.

When [which-key.nvim](https://github.com/folke/which-key.nvim) is installed,
the `<leader>cn` prefix is automatically labeled "buffer-ctx: copy context".
Set `which_key = false` to disable this.

See [Configuration](configuration.md) for the exact option shapes, and
[docs/BINDINGS.md](BINDINGS.md) for a cheatsheet of every keymap, user
command, and autocommand.
