# buffer-ctx.nvim features

buffer-ctx.nvim generates small pieces of text about the current buffer —
its path, its Lua module name, a timestamp, a UUID, a LuaLS annotation, a
code skeleton — and either inserts them at the cursor (`:Insert {subcmd}`)
or copies them to the system clipboard (`:Copy {subcmd}`). Two independent
subsystems, `:Format` and `:Mark`, live alongside that core and are
documented in their own files here since they don't go through the
`:Insert`/`:Copy` dispatch at all.

Grouped by theme:

- [CONTEXT.md](CONTEXT.md) — the `:Insert`/`:Copy` subcommands that describe
  *where you are*: path, module, location, timestamp, UUID, env var, git
  revision, buffer info.
- [ANNOTATIONS.md](ANNOTATIONS.md) — LuaCATS/LuaLS annotation generation.
- [TEMPLATES.md](TEMPLATES.md) — multi-line boilerplate and VSCode-format
  snippets, plus the optional Telescope picker.
- [FORMAT.md](FORMAT.md) — the `:Format` subsystem: buffer/selection
  formatting operations, independent of `:Insert`/`:Copy`.
- [MARK.md](MARK.md) — the `:Mark` subsystem: persistent per-line marks.

For the exact keymap/command/autocommand surface, see
[../BINDINGS.md](../BINDINGS.md). For per-subcommand argument reference,
see [../commands.md](../commands.md). This folder documents what each
feature *is and why it exists*; those two files document the exact syntax.
