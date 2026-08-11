# Mark

The `:Mark` command tree — toggle a visual marker on any line and yank
every marked line in a buffer to the clipboard in one shot. Independent
of `:Insert`/`:Copy`/`:Format`, registered as its own command, and can be
disabled entirely with `opts.mark = false`.

## Extmark-anchored line marking

- **Tab:** true
- **Module:** `mark/init.lua` (`M.toggle`, `M.yank`)
- **Keymaps:** [`<S-m>`, `<C-p>`](../BINDINGS.md#mark)
- **Usercmds:** `:Mark toggle`, `:Mark yank`, plus the compat aliases
  `:MarkLineToggle` / `:MarkLinesYank`
- **Config:** `opts.mark.sign.text` (default `●`), `opts.mark.sign.hl`
  (default `ErrorMsg`)

`toggle` places or removes a marker (sign-column glyph on Neovim 0.10+,
falling back to a virtual-text overlay on 0.9) on the current line.
`yank` collects every marked line in the buffer, sorted by current line
number, and writes them newline-joined to the system clipboard through
the same fallback-aware sink `:Copy` uses.

### Why marks are anchored by extmark ID, not line number

The first version of this feature keyed marks by raw line number. Inserting
or deleting a line above a mark shifted every line below it, but a plain
integer table key can't move — so the visual indicator and the underlying
mark data silently drifted apart after any edit above a mark, and `:Mark
yank` would copy whatever text had since moved into that line slot rather
than the line the user actually marked. See
[`../ROADMAP/anchor-stable-marks.md`](../ROADMAP/anchor-stable-marks.md)
for the full writeup.

The fix: every mark is identified by its extmark ID, and its line number is
always *resolved* fresh from that extmark at read time (`toggle`, `yank`,
and the "is this line already marked" check all go through the same
`resolve_line`). Neovim moves an extmark automatically as the buffer is
edited, so the mark now tracks its line the same way a breakpoint or a
diagnostic does — through any number of edits above it, without needing to
be told.

Two 0.10 extmark features are used when available, gated behind one
`extmark_v10()` check:

- `sign_text`/`sign_hl_group` on the extmark itself, so the sign-column
  rendering rides on the very same extmark that carries the mark's
  identity — one tracking mechanism, not two kept in sync by hand. On 0.9
  (the plugin's documented floor) a real `sign_place()` sign is placed
  alongside instead, keyed by the same extmark ID.
- `invalidate = true, undo_restore = false`, so deleting a marked line
  deletes the extmark outright instead of letting it collapse onto the
  following line — without this, deleting a marked line would silently
  transfer the mark onto whatever line took its place. On 0.9 a deleted
  marked line still slides the mark onto its neighbour; better than the
  old raw-line-number behaviour, but not exact.

### Mark state doesn't outlive the buffer

Mark state is stored per-buffer (`buf → { [extmark_id] = true }`) and is
cleared automatically on `BufDelete`/`BufWipeout` via the
`BufferCtxMarkCleanup` autocommand group, so a long Neovim session doesn't
accumulate mark state for buffers that no longer exist.
