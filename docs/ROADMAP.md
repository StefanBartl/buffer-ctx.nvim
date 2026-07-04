# buffer-ctx.nvim — Roadmap

## Implemented (v0.1)

- `:Insert` / `:Copy` with shared subcommand catalog
- `filepath` — buffer path (cwd/abs/nvim, lua/unix/win, depth)
- `filename` — basename with/without extension
- `module` — Lua module path as require() / @module / js / c / generic
- `location` — path:line of current cursor
- `timestamp` — 8 formats, UTC flag
- `uuid` — v4, 4 formats
- `annotation` — module/class/field/param/return/alias/function (interactive)
- `boilerplate` — 13 templates across Lua, Neovim, HTML, guard
- `env` — environment variable lookup
- Smart tab completion per subcommand
- 3 configurable keymaps: `<leader>cnl/m/f`
- Lua API: `setup()`, `insert()`, `copy()`
- `:checkhealth buffer_ctx`
- Optional lib.nvim: uses `lib.nvim.notify` when installed, falls back to plain `vim.notify`
- Optional which-key: `<leader>cn` group label when installed (`which_key = false` to disable)
- `config/` (DEFAULTS + merge) and `bindings/` (keymaps, usrcmds, autocmds, which_key) module split
- `docs/BINDINGS.lua` — machine-readable keymap/command cheatsheet
- `docs/TESTS/` — headless spec suite for `ops/*` and `util/path.lua`

---

## Geplante Features

### High Priority

- **`:Insert snippet {name}`** — VSCode-kompatible Snippets aus einer YAML/JSON-Datei laden
  und als Boilerplate einfügen; Alternative zu einem vollständigen Snippet-Plugin

- **`filepath nvim_module` als alias für `module`** — Konsistenz: `:Copy filepath nvim_module`
  → gleicher Output wie `:Copy module`; nur ein Eintrag in der Completion aber beide Pfade

- **`:Copy location` mit Zeilen-Bereich** — `:Copy location range` → "path:L1-L2" für
  Visual-Mode-Selektion; nützlich für Code-Review-Kommentare und GitHub-Links

### Annotation Erweiterungen

- **`:Insert annotation overload`** — `---@overload fun(…):…` Annotation; fehlt noch im Catalog
- **`:Insert annotation diagnostic`** — `---@diagnostic disable-next-line: …`
- **`:Insert annotation deprecated`** — `---@deprecated Reason` mit Pflicht-Message
- **`Copy annotation function`** → multi-line clipboard mit `\n` (bereits technisch machbar)

### Boilerplate Erweiterungen

- **`lua-test`** — Minimal-Test-Stub für busted: `describe / it / assert.are.equal`
- **`lua-enum`** — Enum-Pattern: Tabelle + `---@alias` in einem Block
- **`html-table`** — Einfache `<table>` mit 3×3 Zeilen und Thead
- **`html-section`** — `<section>` mit h2 + p als Artikel-Gerüst
- **`md-frontmatter`** — YAML-Frontmatter Block für Markdown-Dateien

### Neue Subcommands

- **`git`** — Aktuellen Git-Commit-Hash einfügen/kopieren; Modi: `hash`, `short`, `branch`, `tag`
  Nützlich für Changelogs und Debug-Output

- **`date`** — Alias für `timestamp iso-date`; kurzer, intuitiver Befehl

- **`linecount`** — Zeilenanzahl des aktuellen Buffers (nützlich für Dokumentations-Verweise)

- **`bufnr`** — Aktuellen Buffer-Handle einfügen (Debug / Lua-Scripting)

### Integration

- **Telescope-Picker für Boilerplate** — `:Telescope buffer_ctx boilerplate` mit Live-Preview
  der generierten Lines; erfordert optionale Telescope-Dependency

### DX / UX

- **`:Insert boilerplate` ohne arg → `vim.ui.select`** — wenn kein Template-Name übergeben,
  interaktive Auswahl der verfügbaren Keys; vermeidet Tab-Completion-Abhängigkeit

- **`env` mit Completion aus `vim.env`** — Liste der gesetzten Umgebungsvariablen als
  Tab-Completion (schon in `vim.env` verfügbar, nur Iter-Logik nötig)

- **Sticky `--utc` via Config** — `timestamp = { utc = true }` in der Config damit alle
  Timestamps standardmäßig UTC sind ohne manuellen `--utc` Flag

---

## Nicht geplant

- **Clipboard-Zwischenspeicher / History** — Scope von `nvim-cmp` oder neoclip.nvim
- **Datetime-Arithmetik** — (addiere N Tage) gehört in ein eigenes Plugin
- **Remote-Pfade (SSH/SFTP)** — außerhalb des "Buffer-Kontext"-Scopes
