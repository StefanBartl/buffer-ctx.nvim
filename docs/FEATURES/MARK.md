# Mark

The `:Mark` command tree — toggle a visual marker on any line and yank
every marked line in a buffer to the clipboard in one shot. Independent
of `:Insert`/`:Copy`/`:Format`, registered as its own command, and can be
disabled entirely with `opts.mark = false`.

## Extmark-anchored line marking

- **Tab:** true
- **Module:** `mark/init.lua` (`M.toggle`, `M.toggle_range`, `M.clear`,
  `M.yank`)
- **Keymaps:** [`<S-m>`, `<C-p>`](../BINDINGS.md#mark), plus an unset
  `keymaps.clear`
- **Usercmds:** `:Mark toggle [category]` (range-capable), `:Mark clear
  [category]`, `:Mark yank [category]`, plus the compat aliases
  `:MarkLineToggle` / `:MarkLinesYank`
- **Config:** `opts.mark.sign.text` (default `●`), `opts.mark.sign.hl`
  (default `ErrorMsg`), `opts.mark.categories` (default `{}`)
- **Tests:** `TESTS/mark_spec.lua`

`toggle` places or removes a marker (sign-column glyph on Neovim 0.10+,
falling back to a virtual-text overlay on 0.9) on the current line.
`yank` collects every marked line in the buffer, sorted by current line
number, and writes them newline-joined to the system clipboard through
the same fallback-aware sink `:Copy` uses.

## Marking a range (2026-08-24)

`3<S-m>` marks the cursor line and the two below it, clamped to the end of
the buffer; `:'<,'>Mark toggle` marks a Visual selection. Both close audit
entries — a count-support one and a flag/option one that turned out to be the
same feature seen twice.

**Deliberately not a per-line toggle.** Over a five-line selection with two
lines already marked, toggling each line leaves a checkerboard, which looks
broken rather than useful. So: if any line in the range is unmarked (or
marked in another category), the whole range is marked; only when every line
already carries that category does the range unmark. Reversed bounds are
normalized, since a selection made upwards hands them over that way.

## Categories (2026-08-24)

`opts.mark.categories` adds named appearances beyond `default`, so marks can
mean different things in the same buffer:

```lua
mark = {
  categories = {
    { name = "todo", text = "●", hl = "WarningMsg" },
    { name = "done", text = "●", hl = "DiagnosticOk" },
  },
},
```

`:Mark toggle todo` marks in that category; `:Mark yank todo` and
`:Mark clear todo` filter by it. Names tab-complete, and an unknown one is
refused with the configured list rather than silently falling back.

The category is stored as the *value* in the per-buffer mark table
(`buf → { [extmark_id] = category }`), which used to be a plain `true`. That
is what lets yank and clear filter without a second table to keep in sync.

Re-marking a line that already carries a different category **replaces** it
rather than unmarking: asking for "todo here" on a "done" line means you want
todo, not nothing.

`opts.mark.sign` still configures the `default` category, so a config written
before categories existed keeps working untouched.

## Clearing (2026-08-24)

`:Mark clear [category]` removes every mark in the buffer, or only one
category's. Before this the only way to unmark was toggling each line
individually — which for a buffer full of marks means finding them first.
`keymaps.clear` binds it; unset by default, like every other addition here.

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
