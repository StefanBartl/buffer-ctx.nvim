# Zentrale Prinzipien — Audit für buffer-ctx.nvim

> Anwendung der Checkliste [Zentrale-Prinzipien](file:///E:/repos/Notes/MyNotes/Checklists/Lua/Zentrale-Prinzipien.md)
> auf buffer-ctx.nvim.

**Status: vollständig erfüllt, keine offenen Punkte** (Audit 2026-07-04,
Nacharbeit abgeschlossen 2026-07-18).

Bewusste, dauerhafte Abweichung (kein Handlungsbedarf):

- **`lib.augroup` nicht genutzt** — buffer-ctx registriert genau einen
  Autocmd (`BufferCtxMarkCleanup` in `mark/init.lua`), zu simpel für einen
  eigenen Wrapper.

## Literatur und Referenzen

- [Arch&Coding.md](./Arch&Coding.md) · [Checklist.md](./Checklist.md)
- Quell-Checkliste: `E:/repos/Notes/MyNotes/Checklists/Lua/Zentrale-Prinzipien.md`
