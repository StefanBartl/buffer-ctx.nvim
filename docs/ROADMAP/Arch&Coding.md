# Architektur- & Coding-Regeln — Audit für buffer-ctx.nvim

> Anwendung der Checkliste [Arch&Coding-Regeln](file:///E:/repos/Notes/MyNotes/Checklists/Lua/Arch&Coding-Regeln.md)
> auf buffer-ctx.nvim. Nur die **normativen** Abschnitte (§1–11 + Annotationen/
> Naming/Types) sind hier auditiert; die CPU-/Table-/String-Benchmark-Kapitel
> sind Referenzmaterial ohne Einzel-Check.

Legende: ✅ erfüllt · ⚠️ bewusste Abweichung / offener Punkt · ❌ Lücke · n/a nicht zutreffend

## §1 Sicherheitsprinzipien & Fehlerbehandlung — ✅

| Regel | Status | Beleg / Anmerkung |
| --- | --- | --- |
| `pcall` bevorzugt | ✅ | [`format/init.lua`](../../lua/buffer_ctx/format/init.lua) kapselt jeden Subcommand-Handler in `pcall`; [`boilerplate/init.lua`](../../lua/buffer_ctx/ops/boilerplate/init.lua) lädt Template-Module via `pcall(require, …)`. |
| Type Guards & Literal Checks | ✅ | Durchgängig `if not name or name == ""`, `type(...) == "table"` vor Zugriffen, z. B. [`filepath.lua`](../../lua/buffer_ctx/ops/filepath.lua), [`config/init.lua`](../../lua/buffer_ctx/config/init.lua). |
| Explizite Rückgaben | ✅ | Alle `ops/*`-Funktionen geben `result, err` zurück statt intern zu failen — sehr konsequent (`filepath.get_path`, `module.get_statement`, `location.get`, `env.get`, `boilerplate.get`, …). |
| Kein `notify()` in Low-Level-Code | ✅ | `ops/*` notifyt nie selbst; nur die Sink-Schicht (`commands.lua`, `util/clip.lua`, `bindings/keymaps.lua`) meldet Fehler an den User. |
| `safe_call`-Wrapper `{ok,result,err}` | ⚠️ | Nicht verwendet — direktes `pcall`/`result,err`-Tupel. Für den Scope (kurze synchrone Text-Operationen) ausreichend, kein Envelope-Overhead nötig. |
| Strukturierte Fehlertypen | ⚠️ | Nur String-Fehlermeldungen (`"unnamed buffer"`, `"not inside a /lua/ directory"`, …), keine `InvalidStateError`-artigen Tags. Bewusst einfach gehalten — kein Aufrufer wertet Fehlertypen aus. |
| `@error`/`@raises` Tags | n/a | Keine werfenden APIs; alle Fehler laufen über Rückgabewerte, nicht `error()`. |
| Private Funktionen lokal | ✅ | Interne Helfer sind `local function` (z. B. `sink_text`/`sink_lines` in `commands.lua`, `ensure_sign`/`use_signcolumn` in `mark/init.lua`). |
| Argumente typisiert übergeben | ✅ | Durchgängige `@param`-Annotationen in allen `ops/*`-Modulen. |
| Buffer-Handle-Validierung vor API-Zugriff | ✅ | [`mark/init.lua`](../../lua/buffer_ctx/mark/init.lua) `M.toggle`/`M.yank` prüfen seit 2026-07-04 `nvim_buf_is_valid()`, bevor `nvim_buf_set_extmark`/`nvim_buf_get_lines` aufgerufen werden — analog zu `util/cursor.lua`. |

## §2 Modularisierung & Strukturprinzipien — ✅

| Regel | Status | Beleg |
| --- | --- | --- |
| Modul = eine Verantwortung | ✅ | `ops/{filepath,module,timestamp,uuid,annotation,location,env}.lua`, `format/{column_align,table_fmt,text_width,filter_lines,enum_lines,misc}.lua`, `mark/init.lua` — je ein Zweck. |
| Reine Funktionen bevorzugen | ✅ | `uuid.format`, `timestamp.format_timestamp`, `filepath._format_segments`, `util/path.*` sind seiteneffektfrei und direkt testbar (siehe `docs/TESTS/`). |
| Lokale statt globale Funktionen | ✅ | Keine globalen Funktionen; interne Helfer sind `local`. |
| Entwurfsmuster wenn sinnvoll | ✅ | Registry-Pattern zweimal: `commands.lua`s `DISPATCH`-Tabelle und `format/init.lua`s `register_subcommand`/`subcommands`-Registry sowie `boilerplate/init.lua`s `REGISTRY`. |
| Tools via Registry | ✅ | Siehe oben — drei unabhängige, konsistente Registries statt if/elseif-Ketten. |
| Keine globalen States | ✅ | Einziger Modul-State ist `config._active` (in `config/init.lua`), Zugriff nur über `get()`; `mark/init.lua`s `marked`-Tabelle ist modul-lokal, kein `_G.*`. |
| Pure Functions wo möglich | ✅ | Siehe oben. |

## §3 Buffer- & Window-Management — ✅

- buffer-ctx öffnet **keine** eigenen Fenster/Floats → `open_window`/`close_window`/`cleanup_all`/UI-State sind n/a.
- `util/cursor.lua`: ✅ vorbildlich — `nvim_win_is_valid`/`nvim_buf_is_valid` vor jeder Mutation, Cursor-Spalte wird geclamped (`math.min(col, #line)`).
- `mark/init.lua`: ✅ seit 2026-07-04 — `nvim_buf_is_valid(bufnr)`-Guard in `M.toggle`/`M.yank` vor Sign-/Extmark-/Line-Zugriffen, analog zu `util/cursor.lua`.
- Race Conditions / Defer-Revalidierung: n/a — buffer-ctx nutzt **kein** `vim.defer_fn`/async; alle Operationen laufen synchron im Command-/Keymap-Handler.

## §4 Methoden, Metatables & Datenmodelle — n/a (bewusst funktional)

buffer-ctx ist **funktional**, nicht OO: keine Metatables, kein `__index`, keine Getter/Setter-Objekte außer dem simplen `config.get()`. Für ein zustandsarmes Text-Utility-Plugin die einfachere, testbarere Wahl — kein Handlungsbedarf.

## §5 Dokumentation & Annotationen — ✅ (2 Abweichungen)

| Regel | Status | Beleg / Anmerkung |
| --- | --- | --- |
| Datei-Tags `@module/@brief/@description` | ✅ | Jede Quelldatei trägt mindestens `@module`; komplexere Module (`format/init.lua`, `mark/init.lua`, `bindings/*.lua`) zusätzlich `@brief`/`@description`. |
| Kommentare pro Funktion `@param/@return` | ✅ | Durchgängig in `ops/*`, inkl. `@return nil`-Fällen. |
| Konsistentes englisches Naming | ✅ | snake_case durchgehend, englisch. |
| Explizite Typisierungen `@alias/@field` | ✅ | Zentral in [`@types.lua`](../../lua/buffer_ctx/@types.lua) (`BufferCtx.Config`, `BufferCtx.FilepathOpts`, `BufferCtx.MarkConfig`, …). |
| Modulverlinkung `@see` | ⚠️ | Kaum genutzt — kein `@see`-Tag im Code gefunden. Kleiner, unkritischer Nice-to-have. |
| **`/types`-Ordner pro Subverzeichnis** | ❌ | Die Checkliste verlangt „Jede Ebene mind. eine types-file". buffer-ctx hat nur **ein** zentrales `@types.lua` auf Root-Ebene; `format/`, `mark/`, `bindings/`, `ops/`, `ops/boilerplate/` haben **keine** eigenen `types/init.lua`-Anker (anders als `cascade.nvim`s `lists/types/init.lua` / `cycle/types/init.lua`). Bewusste Vereinfachung bisher — Repo ist klein genug, dass ein zentrales `@types.lua` reicht, aber weicht von der Konvention ab. |
| README deutsch + `doc/*.txt` englisch | ⚠️ | Diese Regel gilt für **`nvim/config`-Module**. buffer-ctx ist ein **publiziertes Standalone-Plugin** → README bewusst **englisch** (gleiche Konvention wie bei `cascade.nvim`, `sessions.nvim`). |

## §6 Testbarkeit & Lesbarkeit — ✅

| Regel | Status | Beleg |
| --- | --- | --- |
| Klein & fokussiert (SRP) | ✅ | Siehe §2. |
| Klarheit vor Kürze | ✅ | Keine "clevere" Kurzschreibweise auf Kosten der Lesbarkeit. |
| Testbarkeit durch Design | ✅ | Keine Hardcoded States; `ops/*` sind größtenteils pure oder mit klar isoliertem Buffer-Zugriff. |
| Separater Test-Entry | ✅ | [`docs/TESTS/run.lua`](../TESTS/run.lua) + `harness.lua` + 2 Specs (`path_spec.lua`, `ops_spec.lua`). |
| Snapshot/Restore | n/a | Kein langlebiger State zum Snapshotten (`mark`s `marked`-Tabelle ist der einzige State, siehe Zentral-Prinzipien-Audit). |

## §7 Fehlerbehandlung & Validierung — ⚠️ (bewusst, siehe §1)

`safe_call`/strukturierte Fehlertypen bewusst nicht verwendet — direktes `result,err`-Tupel deckt den synchronen, kleinen Scope ab. Kein offener Punkt mehr (Buffer-Validierung in `mark/init.lua` ist behoben, siehe §1/§3).

## §8 Performance & Speicher — ✅

| Regel | Status | Beleg |
| --- | --- | --- |
| Lokale Variablen für Hot Paths | ✅ | `local api = vim.api`, `local fn = vim.fn` als Top-of-File-Alias in praktisch jedem `ops/*`-Modul. |
| String-Concat in Loops vermeiden | ✅ | `commands.lua`s `sink_lines` nutzt `table.concat(lines, "\n")`; `mark.yank` sammelt Zeilen in einer Tabelle vor `table.concat`. |
| Memoization | n/a | Keine teuren wiederholten Berechnungen (kein Pattern-Compile o. Ä. wie bei `cascade.nvim`). |
| Debounced Writes | n/a | Keine kontinuierlichen Schreibvorgänge (alles ist Ad-hoc-Insert/Copy auf expliziten Command). |
| Weak-Tables / GC-Steuerung | ✅ | `mark/init.lua`s `marked`-Tabelle wird seit 2026-07-04 per `BufDelete`/`BufWipeout`-Autocmd (`BufferCtxMarkCleanup`-Augroup) bereinigt, sobald ein Buffer verschwindet — kein unbegrenztes Wachstum mehr über eine lange Session. |

## §9–§11 Cache / Weak Tables / Spezialfälle — n/a

Kein persistenter Cache, keine Dual-Representation, keine FIFO/History-Strukturen.

## Import-Reihung & Alias-Regeln — ✅

- Requires folgen der vorgegebenen Reihung: System/Kern (`vim.api`/`vim.fn`) → projektinterne Utils (`buffer_ctx.util.*`) → Feature-Module. ✅
- Lokale Aliase für heiße Pfade: vorhanden wo sinnvoll (`local api/fn`); keine tight loops über 1M Calls, daher keine weitere Mikro-Optimierung nötig. ✅

---

## Fazit & Plan

buffer-ctx.nvim folgt den Regeln weitgehend. **Bewusste, unkritische Abweichungen:**

1. **Kein `safe_call`/Error-Envelope** (§1/§7) — direktes `result,err`-Tupel genügt dem Scope.
2. **Funktionaler Stil statt Metatables** (§4) — passender für ein zustandsarmes Utility-Plugin.
3. **README englisch** (§5) — Plugin ist veröffentlicht, nicht Config-Modul.

**Behoben (2026-07-04, nach diesem Audit):**

1. ~~`mark/init.lua`: fehlende `nvim_buf_is_valid()`-Guards~~ — behoben in `M.toggle`/`M.yank`.
2. ~~`mark/init.lua`: kein Cleanup der `marked`-Tabelle bei Buffer-Löschung~~ — `BufDelete`/`BufWipeout`-Autocmd ergänzt.

**Verbleibende offene Punkte** (niedrige Priorität, optional):

1. **Fehlende `/types`-Anker-Ordner pro Submodul** (§5) — optional, da zentrales `@types.lua` aktuell ausreicht; nur relevant, falls das Repo deutlich wächst.
2. **Kein CI/Linter** (§7 der Master-Checkliste) — siehe `Checklist.md`-Audit.

## Literatur und Referenzen

- [Zentral-Prinzipien.md](./Zentral-Prinzipien.md) · [Checklist.md](./Checklist.md)
- Quell-Checklisten: `E:/repos/Notes/MyNotes/Checklists/Lua/`
