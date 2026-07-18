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
| Buffer/Window validieren | 🔴 | ✅ | `util/cursor.lua` vorbildlich; `mark/init.lua` prüft seit 2026-07-04 ebenfalls `nvim_buf_is_valid` vor Sign-/Extmark-Zugriff — siehe [Arch&Coding.md](./Arch&Coding.md) §1/§3. |
| Keine globalen States | 🔴 | ✅ | Nur `config._active` (modul-intern, `get()`-Zugriff) und `mark`s buffer-lokale `marked`-Tabelle; kein `_G.*`. |
| Single Responsibility | 🔴 | ✅ | Ein Modul = ein Zweck (`ops/uuid.lua`, `ops/timestamp.lua`, `format/table_fmt.lua`, …). |
| UI-Cleanup | 🟡 | n/a | Keine Fenster/Floats zu bereinigen. |
| Performance-Hotspots | 🟡 | ✅ | `table.concat` statt Concat-in-Loop (`commands.lua sink_lines`, `mark.yank`). |
| Annotationen vollständig | 🟡 | ✅ | Seit 2026-07-18 vollständig. Die `redundant-return-value`-Diagnostics an `uuid.generate`/`format` und `util/path.get_module_path` waren **kein** reines Annotations-Problem: die Funktionen gaben `str:gsub(...)` direkt zurück und lieferten damit `(string, count)` statt eines Strings. Behoben durch Klammerung, mit `select("#", …)`-Regressionstests. |
| Testbarkeit (pure functions) | 🟡 | ✅ | `docs/TESTS/{path_spec,ops_spec}.lua` deckt `util/path.lua` + 6 `ops/*`-Module ab. |
| Import-Reihenfolge | 🟢 | ✅ | System (`vim.api`/`vim.fn`) → Utils (`buffer_ctx.util.*`) → Feature-Module. |

### Bonuspunkt: `lib`-Modul — ✅ (soft: notify, map, path, clip)

Alle über geguardete Bridges mit nativem Fallback, damit das publizierte Plugin
standalone bleibt:

| Bereich | Bridge | Fallback |
| --- | --- | --- |
| Notify | [`util/notify.lua`](../../lua/buffer_ctx/util/notify.lua) → `lib.nvim.notify` | `vim.notify` |
| Keymaps | [`util/map.lua`](../../lua/buffer_ctx/util/map.lua) → `lib.nvim.map` (seit 2026-07-18) | `vim.keymap.set` |
| Pfade | [`util/path.lua`](../../lua/buffer_ctx/util/path.lua) → `lib.nvim.lua_ls`/`cross.fs` | lokale Implementierung |
| Clipboard | [`util/clip.lua`](../../lua/buffer_ctx/util/clip.lua) → `lib.nvim.cross.copy_to_clipboard` | `setreg` |

Beide `util/*`-Bridges melden ihren aktiven Pfad an `:checkhealth buffer_ctx`.
`lib.augroup`: nicht genutzt — der einzige Autocmd (`BufferCtxMarkCleanup`) ist
zu simpel für einen Wrapper. `lib.cross`/`memo`/`lazy`/`hover_select`: n/a bzw.
eigene, einfachere Lösung (siehe [Zentral-Prinzipien.md](./Zentral-Prinzipien.md)).

## PR-Review-Checkliste

### 1. Sicherheit & Fehlerbehandlung — ✅
- pcall/Guards/explizite Rückgaben/kein Low-Level-notify: ✅
- `safe_call`-Envelope + strukturierte Fehlertypen: ⚠️ bewusst nicht — direktes `result,err`-Tupel, keine Error-Objekte.
- Guards vor API: ✅ (siehe `mark/init.lua`-Fix oben).

### 2. Modularität & Struktur — ✅
- SRP ✅, keine Globals ✅, reine Funktionen wo möglich ✅, interne Helfer lokal ✅.
- Registry: `commands.lua`s `DISPATCH`, `format/init.lua`s `register_subcommand`, `boilerplate/init.lua`s `REGISTRY` ✅ — drei konsistente Registry-Patterns statt if/elseif-Ketten.
- `/config`-Ordner mit `DEFAULTS.lua`: ✅ (`config/{init,DEFAULTS}.lua`, seit 2026-07-04 Refactor).

### 3. Buffer-/Window-Management — ✅ (Fenster n/a)
- Handle-zuerst-binden + Gültigkeit prüfen: ✅ in `util/cursor.lua` und `mark/init.lua`.
- Race Conditions / Defer-Revalidierung: n/a — kein `vim.defer_fn`/async, alles synchron im Handler.

### 4. UI-State-Management — n/a
Kein UI-State (keine Fenster/Floats).

### 5. Dokumentation & Annotationen — ✅
Kopf-Tags ✅, Funktions-Tags ✅, `@see`-Querverweise seit 2026-07-18 ✅,
Aliase/Felder zentral in `@types.lua` ✅, **`/types`-Anker-Ordner** pro
Subverzeichnis seit 2026-07-04 in `format/`, `mark/`, `ops/` vorhanden (siehe
[Arch&Coding.md](./Arch&Coding.md) §5).

### 6. Testbarkeit & Lesbarkeit — ✅
Pure Functions ✅, Test-Entry `docs/TESTS/run.lua` ✅ (jetzt inkl.
`format_spec.lua`/`mark_spec.lua`). DI: Config wird als `opts` durchgereicht
(kein Hard-Wiring) ✅.

### 7. Tooling — ✅
- Lua LS: `.luarc.json` vorhanden (`diagnostics.globals=vim`, `workspace.library`) ✅ (seit 2026-07-04).
- CI: `.github/workflows/ci.yml` seit 2026-07-18 ✅ — drei Jobs, alle grün:
  - **test**: `docs/TESTS/run.lua` headless auf Neovim `stable` **und** `nightly`.
  - **health**: `setup()` + `:checkhealth buffer_ctx` müssen sauber laden.
  - **lint**: `luacheck` als **harter Gate** (0 Warnungen / 0 Fehler über 47
    Dateien), `stylua --check` bewusst advisory (`continue-on-error` auf
    **Step**-Ebene — ein fehlgeschlagener Step überspringt sonst die
    Folge-Steps, wodurch luacheck zunächst gar nicht lief). Konfig:
    `.stylua.toml`, `.luacheckrc`.
    **Einziger verbleibender, optionaler Folgeschritt:** `stylua lua/ docs/TESTS/`
    einmal anwenden, Diff reviewen, dann auch dieses Gate scharf schalten.
  - luacheck fand dabei zwei echte Leichen aus dem `lib.lua.uuid`-Refactor
    (`rand_hex` unerreichbar, ungenutztes `notify`-require in `boilerplate/`).
- CI läuft bewusst **ohne** `lib.nvim`: die Library ist Soft-Dependency, damit
  deckt CI den Standalone-Fallback-Pfad ab (`docs/TESTS/run.lua` bricht seither
  nicht mehr ab, wenn `lib.nvim` fehlt).

## Coding-Checkliste

- **A. Strings & Tabellen** — ✅ kein Concat im Loop (`table.concat` in `commands.lua`/`mark.yank`). Inline-Reserve/`t[i]` nicht nötig (kleine, kurze Arrays wie Boilerplate-Zeilen).
- **B. Performance-Quickwins** — ✅ lokale `api`/`fn`-Aliase in Hot-Path-nahen Modulen; async/uv n/a (keine Hintergrund-Tasks); Debounce n/a (synchron); Memoization n/a (keine teuren wiederholten Berechnungen).
- **C. Neovim-API sicher** — ✅ Guards durchgängig, auch in `mark/init.lua`; Deferred Calls n/a.
- **D. State-/Datenmodelle** — Getter via `config.get()` ✅; Metatables/FIFO n/a (bewusst funktional).
- **E. GC bewusst steuern** — ✅ `mark`s `marked`-Tabelle wird per `BufDelete`/`BufWipeout`-Autocmd bereinigt (siehe Arch&Coding.md §8).
- **F. Lazy-Loading** — ✅ empfohlene Installation `event="VeryLazy"`; Boilerplate-Templates laden lazy pro Key; `setup()` bindet nur, arbeitet nicht.

## Anti-Pattern-Check — ✅
Kein globaler State ✅, API-Guards durchgängig vorhanden ✅, kein String-Concat im Loop ✅, keine Closures im Hot-Loop (kein Hot-Loop vorhanden) ✅, keine Flut kleiner Temp-Tabellen ✅.

## Import- & Dateistruktur-Check — ✅
Import-Reihenfolge ✅, Datei-Header ✅, projektweiter `@types`-Ordner **und**
Subverzeichnis-Anker (`format/`, `mark/`, `ops/`) vorhanden (siehe Arch&Coding.md §5).

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
| Sicherheit | pcall + Guards durchgängig (inkl. `mark/init.lua`) | keine |
| Modularität | SRP, keine Globals, drei saubere Registries | keine |
| Neovim-API | synchron, durchgängig geprüfte Handles | keine |
| Performance | keine Hot-Loops, gebündelte Writes, `mark`-State per `BufDelete` bereinigt | keine |
| Doku/Annotation | zentrales `@types.lua` + Subdir-Anker + `@see`-Links | keine |
| Tests | `docs/TESTS/` Suite grün (4 Specs), in CI auf stable + nightly | keine |
| Tooling | CI vorhanden; stylua-Gate noch advisory | einmalig `stylua` anwenden, dann Gate scharf schalten |
| checkhealth-Modul? | ✅ `:checkhealth buffer_ctx` (lib.nvim/which-key/bindings/format/mark-Status) | keine |

---

## Fazit & Plan

buffer-ctx.nvim erfüllt die Master-Checklist in allen für ein
Buffer-Context-Utility-Plugin relevanten Punkten. **Bewusste Abweichungen**
(kein Handlungsbedarf): kein `safe_call`-Envelope, funktionaler Stil,
README englisch (Plugin-Konvention).

**Verbleibender, optionaler Folgeschritt:**

1. `stylua lua/ docs/TESTS/` einmal anwenden, Diff reviewen, danach im
   CI-Lint-Job `continue-on-error` entfernen (§7).

## Literatur und Referenzen

- [Arch&Coding.md](./Arch&Coding.md) · [Zentral-Prinzipien.md](./Zentral-Prinzipien.md)
- Quell-Checklisten: `E:/repos/Notes/MyNotes/Checklists/Lua/`
