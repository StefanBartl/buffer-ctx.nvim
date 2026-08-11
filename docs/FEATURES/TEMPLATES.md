# Templates

Multi-line code skeletons and reusable snippets — the `:Insert`/`:Copy`
subcommands whose result is several lines instead of one, plus the
optional Telescope UI for picking one.

## Boilerplate templates

18 registered templates covering Lua (module, OOP class, annotated
function stub, busted test, enum + `---@alias`), Neovim glue
(`nvim_create_autocmd` block, `vim.keymap.set` stub), a guard-clause
pattern, Markdown YAML frontmatter, and nine HTML fragment shapes
(figure, code listing, blockquote, formula table, aside, pagination nav,
accordion, table, section). Called without a template key, it opens a
`vim.ui.select` picker of every registered key with its description, so
the feature stays usable without relying on command-line completion.
Templates that accept an id/name argument (most of them) substitute it
into the generated skeleton; `guard-clause` is the one template that
prompts interactively for its own inputs instead of taking a name arg.

- **Module:** `ops/boilerplate/init.lua` (`M.get`, `M.list_keys`,
  `M.describe`) and `ops/boilerplate/templates/*.lua`
- **Usercmds:** `:Insert boilerplate [template] [name]`,
  `:Copy boilerplate [template] [name]`

```
:Insert boilerplate                       → interactive template picker
:Insert boilerplate lua-class MyService   → class skeleton named MyService
```

## Snippets

Loads snippets in the standard VSCode JSON format from files listed in
`opts.snippets.paths`, resolving a snippet by either its display key
("For Loop") or its `prefix` ("forl"). Called without a name, it opens a
picker the same way `boilerplate` does. Placeholders are flattened
rather than expanded — `${1:i}` becomes `i`, a choice placeholder
`${1|a,b|}` becomes its first choice, and bare tabstops (`$0`, `$1`) are
dropped — since buffer-ctx inserts plain text and has no tabstop-navigation
engine of its own.

- **Module:** `ops/snippet.lua`
- **Config:** `opts.snippets.paths` (default `{}`)
- **Usercmds:** `:Insert snippet [name]`, `:Copy snippet [name]`

## Telescope boilerplate picker

With telescope.nvim installed and the extension loaded, `:Telescope
buffer_ctx boilerplate` (or the bare `:Telescope buffer_ctx`) offers the
same template list through Telescope's own fuzzy finder, with a live
preview pane showing the exact lines a template would generate before you
commit to inserting it. The one exception is `guard-clause`: since it
prompts interactively, the preview shows a static placeholder instead of
triggering that prompt just from the cursor hovering an entry.

- **Module:** `lua/telescope/_extensions/buffer_ctx.lua`
- **Config:** requires `require("telescope").load_extension("buffer_ctx")`

This extension only ever loads when Telescope itself requires it, so
buffer-ctx stays fully usable — including every other feature in this
folder — without Telescope installed at all.
