# Contributing to buffer-ctx.nvim

Thank you for your interest! Bugs, ideas and questions are welcome in the
[issue tracker](https://github.com/StefanBartl/buffer-ctx.nvim/issues); pull
requests very welcome.

## Getting the repository into a session

Clone it and either symlink the checkout into your plugin directory or add it to
the runtime path directly:

```lua
vim.opt.rtp:prepend("/path/to/buffer-ctx.nvim")
require("buffer_ctx").setup({})
```

## Ground rules

- Lua only, idiomatic Neovim Lua. 2-space indentation.
- One operation = one file under `ops/`, one subcommand route, one spec.
- Commands are registered through `lib.nvim.bindings.usercmd.composer`, never
  with a bare `nvim_create_user_command` — the composer is what gives the four
  trees their completion and their `document()` output.
- An operation returns a string; whether that string is inserted or copied is the
  caller's decision, not the operation's. That split is the reason `:Insert` and
  `:Copy` share everything below the command layer.
  The one exception under `:Insert`/`:Copy` themselves is a cross-plugin shim
  whose sister plugin's own action already inserts its result at the cursor
  (see `ops/imagepaste.lua`) — that shim is wired as an `:Insert`-only route
  outside the shared dispatch table instead of forcing a fake `:Copy`
  counterpart onto it. `ops/reveal.lua`'s `:RevealInFm`/`:OpenInBrowser` are a
  clearer case of the same thing, but sit entirely outside `:Insert`/`:Copy`
  as their own standalone commands, so they never went through this rule in
  the first place.
- Descriptive commit messages.

## Project layout

| Path | Contains |
| --- | --- |
| `lua/buffer_ctx/ops/` | One file per value the buffer can produce (filepath, module, timestamp, UUID, annotations, boilerplate) |
| `lua/buffer_ctx/format/` | Buffer- and selection-level formatting operations |
| `lua/buffer_ctx/mark/` | Per-line mark state, toggling and yanking |
| `lua/buffer_ctx/reveal/` | `:RevealInFm` / `:OpenInBrowser` — reveal-in-file-manager and open-in-browser for the current buffer |
| `lua/buffer_ctx/bindings/` | The `:Insert` / `:Copy` / `:Format` / `:Mark` route trees and the default keymaps |
| `lua/buffer_ctx/config/` | Defaults and `setup()` validation |
| `lua/buffer_ctx/util/` | Shared helpers |
| `lua/telescope/_extensions/` | The optional telescope picker for boilerplate templates |
| `docs/` | Everything the README links to |
| `TESTS/` | The spec suite, mirroring `lua/buffer_ctx/`'s paths |

## Adding an operation

1. Add the value producer under `lua/buffer_ctx/ops/`, returning a string.
2. Register it as a subcommand on both the `:Insert` and `:Copy` trees in
   `lua/buffer_ctx/bindings/` if it makes sense in both.
3. Add a spec under `TESTS/` next to the existing `ops_spec.lua`.
4. Document it in [`commands.md`](commands.md) and, if it is worth knowing about
   on day one, in [`BINDINGS.md`](BINDINGS.md).

## Tests

`TESTS/` is a [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
busted-style suite; [`TESTS/README.md`](../TESTS/README.md) has the invocation.
[GitHub Actions](../.github/workflows/ci.yml) runs it on every push and PR to
`main`.

## Workflow

1. Fork the repository.
2. Branch as `feature/<name>`.
3. Make the change, add a spec, update the affected pages under `docs/`.
4. Open a PR with a clear description of what changed and why.
