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
- Optional lib.nvim (soft dependency, native fallback throughout): `lib.nvim.notify`
  for notifications, `lib.nvim.map` for keymaps, plus path/clipboard helpers
- Optional which-key: `<leader>cn` group label when installed (`which_key = false` to disable)
- `config/` (DEFAULTS + merge) and `bindings/` (keymaps, usrcmds, autocmds, which_key) module split
- `docs/BINDINGS.md` — machine-readable keymap/command cheatsheet
- `docs/TESTS/` — headless spec suite for `ops/*`, `util/path.lua`, `format/*`, and `mark/*`
- CI (`.github/workflows/ci.yml`) — specs on stable + nightly, checkhealth smoke test

---

## Qualität & Checklist-Audits

buffer-ctx.nvim wurde gegen die drei persönlichen Lua/Neovim-Checklisten
auditiert (2026-07-04, Nacharbeit abgeschlossen 2026-07-18):

- [Arch&Coding.md](Arch&Coding.md) — Architektur- & Coding-Regeln
- [Zentral-Prinzipien.md](Zentral-Prinzipien.md) — zentrale Modul-Prinzipien
- [Checklist.md](Checklist.md) — Master-Checklist (Schnell-Check/PR/Coding)

**Bilanz:** alle drei Audits sind abgearbeitet, es bleiben nur die bewussten
Design-Entscheidungen (kein `safe_call`-Envelope, funktionaler Stil statt
Metatables, README englisch). Sortier-/Datenstruktur-/Bit-Operationen-Kapitel
sind n/a (kein eigener Algorithmus-Code).

Zuletzt geschlossen (2026-07-18):

- `gsub`-Mehrfachrückgabe in `uuid.generate`/`uuid.format`/`path.get_module_path`
  (gaben `(string, count)` statt eines Strings zurück) — Ursache der
  `redundant-return-value`-Diagnostics, mit Regressionstests abgesichert.
- `lib.map`-Soft-Bridge für Keymaps (`util/map.lua`).
- `@see`-Modulquerverweise.
- CI-Workflow (`.github/workflows/ci.yml`): Specs auf stable + nightly,
  `:checkhealth`-Smoke-Test, `luacheck` als harter Gate (0 Warnungen),
  `stylua --check` advisory.
- Zwei tote Code-Reste aus dem `lib.lua.uuid`-Refactor entfernt (`rand_hex`,
  ungenutztes `notify`-require) — von luacheck gefunden.
- `mark.yank` schrieb `"+"` direkt statt über `util/clip` — umgeleitet; damit
  erhält es die lib.nvim-Fallback-Kette und den Unnamed-Register-Write.
  `clip.copy` überlebt jetzt einen fehlenden Clipboard-Provider (pcall-Guard
  + Warnung) statt den Copy komplett fallen zu lassen.

Verbleibender, optionaler Folgeschritt:

1. `stylua lua/ docs/TESTS/` einmal anwenden, Diff reviewen, danach das
   CI-Lint-Gate scharf schalten (`continue-on-error` entfernen).

---

## Geplante Features

### High Priority

- **`:Insert snippet {name}`** — VSCode-kompatible Snippets aus einer YAML/JSON-Datei laden
  und als Boilerplate einfügen; Alternative zu einem vollständigen Snippet-Plugin (lua/buffer_ctx/ops/boilerplate)existiert bereits

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
