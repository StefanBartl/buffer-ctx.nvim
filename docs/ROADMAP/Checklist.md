# Lua/Neovim Master-Checklist — Audit für buffer-ctx.nvim

> Anwendung der [Checklist](file:///E:/repos/Notes/MyNotes/Checklists/Lua/Checklist.md)
> auf buffer-ctx.nvim. Die umfangreichen Kapitel zu **Sortier-/Such-Algorithmen,
> Datenstrukturen (Bäume/Heaps/Filter/Tries) und Bit-Operationen** sind für ein
> Buffer-Context-Utility-Plugin **n/a** (siehe Ende). Fokus hier: Schnell-Check,
> PR-Review, Coding-Checkliste, Anti-Patterns, Struktur.

Legende: ✅ · ⚠️ bewusste Abweichung / offener Punkt · ❌ Lücke · n/a

## Schnell-Check (10 Punkte, vor jedem Merge)

| Prüfschritt | Prio | Status | Beleg |
| --- | --- | --- | --- |
| Fehlerbehandlung (pcall, keine stillen Fehler) | 🔴 | ✅ | `pcall` in `format/init.lua`-Handlern und `boilerplate/init.lua`-Template-Load; `ops/*` geben `result, err` statt zu crashen. |
| Type Guards (type/nil vor API) | 🔴 | ✅ | `if not name or name == ""`-Guards vor jedem `nvim_buf_get_name`-Folgezugriff. |
| Buffer/Window validieren | 🔴 | ⚠️ | `util/cursor.lua` ✅ vorbildlich; `mark/init.lua` ❌ fehlt (`nvim_buf_is_valid` vor Sign-/Extmark-Zugriff) — siehe [Arch&Coding.md](./Arch&Coding.md) §1/§3. |
| Keine globalen States | 🔴 | ✅ | Nur `config._active` (modul-intern, `get()`-Zugriff) und `mark`s buffer-lokale `marked`-Tabelle; kein `_G.*`. |
| Single Responsibility | 🔴 | ✅ | Ein Modul = ein Zweck (`ops/uuid.lua`, `ops/timestamp.lua`, `format/table_fmt.lua`, …). |
| UI-Cleanup | 🟡 | n/a | Keine Fenster/Floats zu bereinigen. |
| Performance-Hotspots | 🟡 | ✅ | `table.concat` statt Concat-in-Loop (`commands.lua sink_lines`, `mark.yank`). |
| Annotationen vollständig | 🟡 | ⚠️ | Meist vollständig; drei Funktionen (`uuid.generate`/`format`, `util/path.get_module_path`) haben `@return string` annotiert, geben aber teils `nil` zurück — LuaLS meldet `redundant-return-value`-Diagnostics (kosmetisch, keine Laufzeit-Auswirkung). |
| Testbarkeit (pure functions) | 🟡 | ✅ | `docs/TESTS/{path_spec,ops_spec}.lua` deckt `util/path.lua` + 6 `ops/*`-Module ab. |
| Import-Reihenfolge | 🟢 | ✅ | System (`vim.api`/`vim.fn`) → Utils (`buffer_ctx.util.*`) → Feature-Module. |

### Bonuspunkt: `lib`-Modul — ✅ (soft, nur notify)

`lib.nvim.notify` via geguardete Bridge [`util/notify.lua`](../../lua/buffer_ctx/util/notify.lua)
(Fallback nativ `vim.notify`). `lib.map`/`lib.augroup`: nicht genutzt (❌, aber
unkritisch — keine Autocmds, Keymaps sind simpel genug für direktes
`vim.keymap.set`). `lib.cross`/`memo`/`lazy`/`hover_select`: n/a bzw. eigene,
einfachere Lösung (siehe [Zentral-Prinzipien.md](./Zentral-Prinzipien.md)).

## PR-Review-Checkliste

### 1. Sicherheit & Fehlerbehandlung — ✅ / ⚠️
- pcall/Guards/explizite Rückgaben/kein Low-Level-notify: ✅
- `safe_call`-Envelope + strukturierte Fehlertypen: ⚠️ bewusst nicht — direktes `result,err`-Tupel, keine Error-Objekte.
- Guards vor API: ⚠️ siehe `mark/init.lua`-Lücke oben.

### 2. Modularität & Struktur — ✅
- SRP ✅, keine Globals ✅, reine Funktionen wo möglich ✅, interne Helfer lokal ✅.
- Registry: `commands.lua`s `DISPATCH`, `format/init.lua`s `register_subcommand`, `boilerplate/init.lua`s `REGISTRY` ✅ — drei konsistente Registry-Patterns statt if/elseif-Ketten.
- `/config`-Ordner mit `DEFAULTS.lua`: ✅ (`config/{init,DEFAULTS}.lua`, seit 2026-07-04 Refactor).

### 3. Buffer-/Window-Management — ⚠️ (Fenster n/a)
- Handle-zuerst-binden + Gültigkeit prüfen: ✅ in `util/cursor.lua`, ❌ in `mark/init.lua` (siehe oben).
- Race Conditions / Defer-Revalidierung: n/a — kein `vim.defer_fn`/async, alles synchron im Handler.

### 4. UI-State-Management — n/a
Kein UI-State (keine Fenster/Floats).

### 5. Dokumentation & Annotationen — ✅ (kleine Lücken)
Kopf-Tags ✅, Funktions-Tags ✅ (bis auf die o. g. `redundant-return-value`-Fälle),
Aliase/Felder zentral in `@types.lua` ✅, aber **kein** `/types`-Ordner pro
Subverzeichnis (siehe [Arch&Coding.md](./Arch&Coding.md) §5).

### 6. Testbarkeit & Lesbarkeit — ✅
Pure Functions ✅, Test-Entry `docs/TESTS/run.lua` ✅. DI: Config wird als `opts` durchgereicht (kein Hard-Wiring) ✅.

### 7. Tooling — ⚠️
- Lua LS: `.luarc.json` vorhanden (`diagnostics.globals=vim`, `workspace.library`) ✅ (seit 2026-07-04).
- Formatter/Linter im CI (stylua/luacheck): ❌ **kein CI** eingerichtet (kein `.github/workflows`). Einziger offener „empfohlen"-Punkt aus diesem Abschnitt.

## Coding-Checkliste

- **A. Strings & Tabellen** — ✅ kein Concat im Loop (`table.concat` in `commands.lua`/`mark.yank`). Inline-Reserve/`t[i]` nicht nötig (kleine, kurze Arrays wie Boilerplate-Zeilen).
- **B. Performance-Quickwins** — ✅ lokale `api`/`fn`-Aliase in Hot-Path-nahen Modulen; async/uv n/a (keine Hintergrund-Tasks); Debounce n/a (synchron); Memoization n/a (keine teuren wiederholten Berechnungen).
- **C. Neovim-API sicher** — ⚠️ Guards vorhanden, aber `mark/init.lua`-Lücke (s. o.); Deferred Calls n/a.
- **D. State-/Datenmodelle** — Getter via `config.get()` ✅; Metatables/FIFO n/a (bewusst funktional).
- **E. GC bewusst steuern** — n/a (keine großen Objekte/Coroutinen; `mark`s `marked`-Tabelle ist klein, aber siehe Cleanup-Punkt in Arch&Coding.md §8).
- **F. Lazy-Loading** — ✅ empfohlene Installation `event="VeryLazy"`; Boilerplate-Templates laden lazy pro Key; `setup()` bindet nur, arbeitet nicht.

## Anti-Pattern-Check — ✅ (mit einer Notiz)
Kein globaler State ✅, API-Guards größtenteils vorhanden (⚠️ `mark/init.lua`-Ausnahme), kein String-Concat im Loop ✅, keine Closures im Hot-Loop (kein Hot-Loop vorhanden) ✅, keine Flut kleiner Temp-Tabellen ✅.

## Import- & Dateistruktur-Check — ⚠️
Import-Reihenfolge ✅, Datei-Header ✅, projektweiter `@types`-Ordner: ⚠️ vorhanden aber **zentral statt pro Subverzeichnis** (siehe Arch&Coding.md §5).

## Performance-Spickzettel — ✅ / n/a
`table.concat`/gebündelte Writes ✅; Weak-Caches, Async/uv, Debounce: n/a für den synchronen, kleinen Scope ohne Hot-Path.

## Sort / Datenstrukturen / Bit-Ops — n/a

buffer-ctx implementiert **keine** eigenen Sortieralgorithmen, Bäume, Heaps,
Filter, Tries oder Bit-Tricks. `format/misc.lua`s `:Format sort` nutzt Lua's
`table.sort` (Standardbibliothek — Checkliste: „Standardbibliothek
bevorzugen" ✅), mit optionalen Flags (`-r`/`-i`/`-n`) für Vergleichsfunktion,
aber keine eigene Sortierimplementierung. Alle Kapitel zu
Sortieralgorithmen-Auswahl, Einfüge-/Lösch-/Update-/Such-Datenstrukturen,
Zeit-/Platzkomplexität-Notation und Bitoperationen sind daher **n/a** für
dieses Repo.

## Reviewer-Notizen

| Bereich | Beobachtung | Empfehlung |
| --- | --- | --- |
| Sicherheit | pcall + Guards fast durchgängig | `mark/init.lua`: `nvim_buf_is_valid()`-Guards ergänzen |
| Modularität | SRP, keine Globals, drei saubere Registries | keine |
| Neovim-API | synchron, meist geprüfte Handles | `mark/init.lua` nachziehen (s. o.) |
| Performance | keine Hot-Loops, gebündelte Writes | `mark`-State: `BufDelete`-Cleanup ergänzen |
| Doku/Annotation | vollständig, zentrales `@types.lua` | optional: `/types`-Anker pro Subdir, falls Repo wächst |
| Tests | `docs/TESTS/` Suite grün (2 Specs) | optional: `format/*`- und `mark/*`-Subcommands abdecken |
| checkhealth-Modul? | ✅ `:checkhealth buffer_ctx` (lib.nvim/which-key/bindings/format/mark-Status) | keine |

---

## Fazit & Plan

buffer-ctx.nvim erfüllt die Master-Checklist in praktisch allen für ein
Buffer-Context-Utility-Plugin relevanten Punkten. **Bewusste Abweichungen**
(kein Handlungsbedarf): kein `safe_call`-Envelope, funktionaler Stil,
README englisch (Plugin-Konvention).

**Offene Handlungspunkte** (siehe [Arch&Coding.md](./Arch&Coding.md) für Details,
zusammengeführt im Gesamt-Implementierungsplan):

1. `mark/init.lua`: `nvim_buf_is_valid()`-Guards in `toggle`/`yank`.
2. `mark/init.lua`: `BufDelete`-Cleanup für die `marked`-Tabelle.
3. CI-Workflow (stylua + luacheck + `docs/TESTS/run.lua` headless) — niedrige Priorität.
4. Optional: `/types`-Anker-Ordner pro Subverzeichnis, falls das Repo wächst.
5. Optional: `docs/TESTS/`-Abdeckung auf `format/*` und `mark/*` erweitern.

## Literatur und Referenzen

- [Arch&Coding.md](./Arch&Coding.md) · [Zentral-Prinzipien.md](./Zentral-Prinzipien.md)
- Quell-Checklisten: `E:/repos/Notes/MyNotes/Checklists/Lua/`
