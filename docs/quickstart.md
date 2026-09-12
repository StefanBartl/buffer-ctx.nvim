# Quickstart

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

See [commands.md](commands.md) for the full subcommand reference and
[keymaps.md](keymaps.md) for the default keys these are bound to.
