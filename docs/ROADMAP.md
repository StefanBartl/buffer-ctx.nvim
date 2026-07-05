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
- `docs/BINDINGS.md` — machine-readable keymap/command cheatsheet
- `docs/TESTS/` — headless spec suite for `ops/*`, `util/path.lua`, `format/*`, and `mark/*`

---

## Qualität & Checklist-Audits

buffer-ctx.nvim wurde gegen die drei persönlichen Lua/Neovim-Checklisten
auditiert (2026-07-04). Ergebnisse und bewusste Abweichungen:

- [Arch&Coding.md](ROADMAP/Arch&Coding.md) — Architektur- & Coding-Regeln
- [Zentral-Prinzipien.md](ROADMAP/Zentral-Prinzipien.md) — zentrale Modul-Prinzipien
- [Checklist.md](ROADMAP/Checklist.md) — Master-Checklist (Schnell-Check/PR/Coding)

**Bilanz:** überwiegend erfüllt; Sortier-/Datenstruktur-/Bit-Operationen-Kapitel
sind n/a (kein eigener Algorithmus-Code). Alle konkreten Funde sind
behoben (2026-07-04):

- ~~`mark/init.lua`: `nvim_buf_is_valid()`-Guards~~ in `toggle`/`yank` ergänzt.
- ~~`mark/init.lua`: `BufDelete`-Cleanup~~ für die `marked`-Tabelle ergänzt.
- ~~`/types`-Anker-Ordner pro Subverzeichnis~~ — `format/types/`, `mark/types/`,
  `ops/types/` ergänzt (analog zu `cascade.nvim`).
- ~~`docs/TESTS/`-Abdeckung für `format/*`/`mark/*`~~ — `format_spec.lua` +
  `mark_spec.lua` ergänzt. Dabei zwei echte Bugs gefunden und behoben:
  `table_fmt.format_table_at_cursor` meldete bei **Erfolg** fälschlicherweise
  einen Fehler (`ok and nil or "err"`-Antipattern), und
  `text_width.reflow_buffer` **crashte** bei jeder mehrzeiligen Eingabe
  (falsche `gsub`-Mehrfachrückgabe an `table.insert` durchgereicht).
- ~~`format/{column_align,enum_lines,misc,table_fmt}.lua` hart auf
  `lib.nvim.notify` requiret~~ — dieselbe stillschweigende Silent-Failure wie
  der ursprüngliche `format/init.lua`/`mark/init.lua`-Fund: ohne `lib.nvim`
  wurden die zugehörigen `:Format`-Subcommands gar nicht erst registriert.

Verbleibender, optionaler Punkt:

1. **CI-Workflow** (stylua + luacheck + `docs/TESTS/run.lua` headless) —
   niedrige Priorität, einziger offener „empfohlen"-Punkt aus Checklist §7.

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
