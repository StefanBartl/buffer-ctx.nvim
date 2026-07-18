# Zentrale Prinzipien — Audit für buffer-ctx.nvim

> Anwendung der Checkliste [Zentrale-Prinzipien](file:///E:/repos/Notes/MyNotes/Checklists/Lua/Zentrale-Prinzipien.md)
> auf buffer-ctx.nvim. Pro Prinzip: Status + Belege im Code.

Legende: ✅ erfüllt · ⚠️ teilweise / bewusst abgewogen · ❌ offen

## Vorbemerkung: `lib`-Nutzung

Die Checkliste fordert die `lib.*`-Library (`lib.notify`, `lib.map`, `lib.augroup`,
…). buffer-ctx nutzt sie als **soft dependency** nur für `notify`, über die
geguardete Bridge [`util/notify.lua`](../../lua/buffer_ctx/util/notify.lua): ist
`lib.nvim` vorhanden, läuft `notify` durch `lib.nvim.notify.create(...)`; sonst
native Fallbacks (`vim.notify`). Bewusst **soft**, weil publiziertes Plugin —
keine harte Abhängigkeit auf die persönliche Library.

| Bereich | lib-Wrapper | Status |
| --- | --- | --- |
| Notify | `lib.nvim.notify` (Fallback `vim.notify`) | ✅ (siehe `util/notify.lua`, `M.using_lib()` für `:checkhealth`) |
| Keymaps | `lib.nvim.map` (Fallback `vim.keymap.set`) | ✅ seit 2026-07-18 — Bridge [`util/map.lua`](../../lua/buffer_ctx/util/map.lua), genutzt von `bindings/keymaps.lua` und `mark/init.lua`; `M.using_lib()` für `:checkhealth`. |
| Autocmd-Gruppe | `lib.augroup` | ⚠️ nicht genutzt — buffer-ctx registriert genau **einen** Autocmd (`BufferCtxMarkCleanup`, `BufDelete`/`BufWipeout` in `mark/init.lua`), zu simpel für einen Wrapper. `bindings/autocmds.lua` bleibt No-Op-Stub. |
| `lib.cross` / memo / lazy / hover_select | — | n/a bzw. eigene Lösung: Cross-Plattform durch reinen String-/Pfad-Handling-Code in `util/path.lua` (siehe Cross-Platform-Fix vom 2026-07-04: `relative_to_cwd` normalisiert jetzt immer auf `/`). |

## 1. Events bündeln, Logik entkoppeln — ✅ (praktisch keine Events)

- Einziger registrierter Autocmd ist `BufferCtxMarkCleanup` (`BufDelete`/`BufWipeout` in `mark/init.lua`), der ausschließlich Mark-State für verschwundene Buffer freigibt — eigene Augroup, ein Callback, nichts zu bündeln.
- `bindings/autocmds.lua` existiert weiterhin nur als dokumentierter Erweiterungspunkt (No-Op).
- Damit entfällt das Prinzip strukturell — es gibt keine Event-Logik zu entkoppeln.

## 2. Eigene Logik lazy laden — ✅

- `setup()` registriert nur Commands (`:Insert`/`:Copy`/`:Format`/`:Mark`) und Keymaps; die eigentliche Arbeit (Path-Parsing, Boilerplate-Generierung, …) läuft erst beim Command-/Keymap-Aufruf.
- README empfiehlt `event = "VeryLazy"` als Standard-Installationsvariante.
- `boilerplate/init.lua` lädt Template-Submodule (`templates/lua.lua`, `templates/html.lua`, …) erst lazy via `require` **innerhalb** von `M.get(key, …)`, nicht beim Modul-Load — Templates, die nie benutzt werden, werden nie geladen. ✅

## 3. Kontext statt Mehrfach-API-Zugriffe — ✅ (kein Context-Objekt nötig)

- Jeder Dispatch (`commands.lua`s `DISPATCH`-Tabelle) ruft **genau einen** `ops/*`-Handler auf, der intern **einmal** `api.nvim_buf_get_name(0)` (bzw. Cursor-Position) abfragt — kein Redundanz-Problem, da nie mehrere `ops`-Funktionen pro Aufruf kombiniert werden.
- Anders als `cascade.nvim` (das ein zentrales `core/context.lua` hat, weil dort mehrere Feature-Module denselben Cursor-Kontext pro Tastendruck brauchen) gibt es bei buffer-ctx keinen Bedarf für ein geteiltes Context-Objekt — jede Subcommand-Funktion ist bereits minimal in ihren API-Zugriffen.

## 4. Autocommand-Gruppen sauber nutzen — ✅

Der einzige Autocmd hängt in einer eigenen, mit `clear = true` angelegten
Augroup (`BufferCtxMarkCleanup`) — kein Anhängen an fremde oder die Default-Gruppe,
kein Doppel-Registrieren bei wiederholtem `setup()`.

## 5. Event oder Command? — ✅

- Ausnahmslos **explizit**: `:Insert`/`:Copy`/`:Format`/`:Mark` + optionale Keymaps. Kein automatisches Verhalten bei Buffer-/Cursor-Events.

## 6. Treesitter notwendig oder nicht? — ✅

- **Kein Treesitter.** Reines String-/Pfad-Pattern-Matching (`gmatch`, `gsub`, `fnamemodify`) in `util/path.lua` und `ops/*`. Für Pfad-Parsing und Markdown-Tabellen-Formatierung (`format/table_fmt.lua`) ist das ausreichend und deutlich leichtgewichtiger.

## 7. Cache vorhanden und explizit? — n/a

- Keine wiederholt teuren Berechnungen, die einen Cache rechtfertigen würden (UUID-Generierung, Timestamp-Formatierung, Pfad-Parsing sind alle O(1)-artig und billig).

## 8. Allokationen im Hot-Path vermeiden — ✅

- buffer-ctx läuft **nie** in `CursorMoved`/`TextChanged`/`BufEnter` — jede Operation ist ein expliziter, seltener Command-/Keymap-Aufruf. "Hot-Path" im Sinne der Checkliste existiert schlicht nicht.
- Einzige nennenswerte Schleife ist `mark.yank`s Sortierung + Zeilensammlung — linear in der Anzahl markierter Zeilen, unkritisch.

## 9. Debugbarkeit eingeplant? — ✅

- `:checkhealth buffer_ctx` ([`health.lua`](../../lua/buffer_ctx/health.lua)) prüft Neovim-Version, `vim.uv`/`vim.loop`, `setreg`, Plugin-Guard, optionale lib.nvim/which-key-Erkennung, `bindings`-Ladbarkeit, sowie Format-/Mark-Subsystem-Status.
- `docs/TESTS/` (headless Spec-Suite) ermöglicht isoliertes Testen der `ops/*`- und `util/path.lua`-Logik ohne UI.

## 10. Laufzeit wichtiger als Startup? — ✅

- Da nichts an `CursorMoved`/`TextChanged`/`BufEnter` hängt, ist Startup-Overhead die einzig relevante Kostenstelle — und die ist minimal (`setup()` registriert nur Commands/Keymaps, keine Berechnung).

## Kurzform (mental) — Ergebnis

| Frage | Antwort für buffer-ctx.nvim |
| --- | --- |
| Wann läuft es? | Nur bei explizitem `:Insert`/`:Copy`/`:Format`/`:Mark`-Aufruf oder Keymap. |
| Muss es jetzt laufen? | Ja — es ist immer eine direkte User-Aktion, kein Hintergrundprozess. |
| Lädt es mehr als nötig? | Nein — Boilerplate-Templates werden lazy pro Key geladen. |
| Läuft es öfter als nötig? | Nein — kein Event-Handler, der wiederholt feuert. |
| Wird Arbeit wiederholt? | Nein, keine erkennbare Redundanz. |
| Ist der Datenfluss klar? | Ja — `Dispatch → ops.get_*() → sink (cursor/clip)`, durchgängig. |

---

## Fazit

buffer-ctx.nvim erfüllt die Zentralen Prinzipien — das weitgehende Fehlen von
Autocmds und Hot-Paths macht die meisten Punkte trivial erfüllt statt aktiv
erarbeitet. Die letzte offene Lücke, der fehlende `lib.map`-Soft-Bridge für
Keymaps, ist seit 2026-07-18 mit [`util/map.lua`](../../lua/buffer_ctx/util/map.lua)
geschlossen. **Keine offenen Punkte.**

## Literatur und Referenzen

- [Arch&Coding.md](./Arch&Coding.md) · [Checklist.md](./Checklist.md)
- Quell-Checkliste: `E:/repos/Notes/MyNotes/Checklists/Lua/Zentrale-Prinzipien.md`
