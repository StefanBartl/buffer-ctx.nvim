# Line marks drift on edit — needs content-stable anchoring

> **Status: implemented.** The fix below shipped; `lua/buffer_ctx/mark/init.lua`
> now keys `marked` by extmark ID, and `docs/TESTS/mark_spec.lua` carries
> regression coverage for all three cases (insert above a mark, delete a
> marked line, yank ordering vs. creation order). This document is kept as
> the rationale record. Two deviations from the proposal as written are
> noted under "As implemented" at the end.
>
> Originally surfaced while designing a
> renumbering-anchor feature for `cascade.nvim`
> ([concept doc](../../../cascade.nvim/docs/ROADMAP/renumbering_markers.md));
> that design explicitly separates "where is a marker stored" from "what does
> a marker point at", and a cross-repo scan afterwards found this module makes
> exactly the mistake that separation is meant to prevent.

## The bug

[`lua/buffer_ctx/mark/init.lua`](../../lua/buffer_ctx/mark/init.lua) stores
marked lines as raw line numbers:

```lua
---@type table<number, table<number, boolean>>
local marked = {}   -- buf → { [lnum] = true }
```

`M.toggle` renders the **visual** indicator as an extmark (or a sign, which
Neovim also tracks across edits) —

```lua
vim.api.nvim_buf_set_extmark(bufnr, VIRT_NS, lnum - 1, 0, {
  virt_text = { { sign_opts.text, sign_opts.hl } },
  virt_text_pos = "overlay",
})
```

— but the **data** (`marked[bufnr][lnum]`) is a plain integer key. Neovim
moves the extmark automatically when lines are inserted or deleted above it;
it does **not** move the table key, because a Lua table has no concept of
"this integer means a line". The visual indicator and the underlying data
silently diverge.

### Repro

1. `:Mark toggle` on line 5 → sign appears on line 5, `marked[buf][5] = true`.
2. Insert 2 lines above line 5 (e.g. `2ggO<Esc><Esc>`) → the sign correctly
   moves to line 7 (Neovim's sign/extmark tracking), but `marked[buf]` still
   has key `5`.
3. `:Mark yank` reads `vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, ...)`
   for `lnum = 5` → **copies the wrong line** (whatever now sits at line 5,
   not the originally marked line).

The bug is invisible in the common case (mark, then immediately yank, no
edits in between) — which is presumably why it hasn't surfaced — but any
edit-then-yank workflow silently yanks the wrong content.

## Fix

Store the extmark ID as the source of truth, not the line number. Extmark IDs
survive edits correctly by construction — that's the entire point of the API.

```lua
---@type table<number, table<number, boolean>>  -- buf → { [extmark_id] = true }
local marked = {}

function M.toggle(lnum, bufnr)
  ...
  local id = vim.api.nvim_buf_set_extmark(bufnr, VIRT_NS, lnum - 1, 0, {
    virt_text = { { sign_opts.text, sign_opts.hl } },
    virt_text_pos = "overlay",
  })
  marked[bufnr][id] = true
end

function M.yank(bufnr)
  ...
  for id in pairs(marked[bufnr]) do
    local pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, VIRT_NS, id, {})
    -- pos[1] is the *current*, edit-adjusted 0-based line
  end
end
```

Two consequences to handle explicitly:

- **Sort order**: currently sorts by `lnum` directly; with extmark IDs, sort
  by the *resolved* current line (`nvim_buf_get_extmark_by_id`), not by ID
  (IDs are assignment order, not buffer order, and diverge from it once
  marks are toggled off/on or lines reordered).
  \
  Note: the `signcolumn`-off branch already uses `nvim_buf_set_extmark` for
  the visual indicator, so this fix doesn't add a new API dependency — it
  reuses the extmark that's already being created, just also treats it as
  the identity instead of throwing the ID away.
- **`sign_place` branch**: the `use_signcolumn()` true-branch places a
  Vim sign (`vim.fn.sign_place`), not an extmark, keyed by `id = lnum` — signs
  also track edits internally, but `sign_place`'s `id` parameter is also an
  arbitrary integer key, not tied to the sign's tracked position. That branch
  needs either its own resolved-position lookup (`sign_getplaced`) or should
  be unified onto the same extmark-backed tracking as the other branch (with
  a sign-column *rendering* on top, rather than two independent tracking
  mechanisms for the same concept).

## As implemented

Two things the proposal above did not anticipate:

1. **An extmark alone does not vanish when its line is deleted.** By default
   it collapses onto the following line, so deleting a marked line silently
   transferred the mark to its neighbour — a smaller version of the very bug
   being fixed. The extmark is therefore created with
   `invalidate = true, undo_restore = false` (Neovim 0.10+), which deletes it
   outright instead. `M.yank` also drops any ID that no longer resolves, so
   dangling entries cannot accumulate in `marked`.

2. **The `sign_place` branch was unified rather than given its own lookup.**
   The proposal offered both options; unification won. On 0.10+ the
   sign-column rendering rides on the same extmark via
   `sign_text`/`sign_hl_group`, so there is exactly one tracking mechanism
   and no second identity to keep in sync. On 0.9 — still the documented
   floor, and the reason this is version-gated at all — a real sign is placed
   alongside, keyed by the extmark ID so the two remain addressable as a
   unit. `unplace_mark` clears both renderings unconditionally, because
   `signcolumn` can be toggled between placing and removing a mark.

The 0.9 path keeps the old collapse-onto-neighbour behaviour for a deleted
line (no `invalidate` there), which is still far better than the raw
line-number keying it replaces.

## Relation to the cascade concept

This is the "(B) verankerung" half of the linked cascade design taken to its
logical minimum: extmarks alone (no persistence, no fingerprinting) are
sufficient to fix this specific bug, because `buffer-ctx` marks are
session-only (cleared on `BufDelete`/`BufWipeout`) — there's no cross-session
requirement here, unlike cascade's renumbering anchors which need to survive
a closed buffer. If persistence across sessions is ever wanted for marks too,
`lib.nvim.store.project` (proposed in
[lib.nvim/docs/ROADMAP/project-store.md](../../../lib.nvim/docs/ROADMAP/project-store.md))
would be the storage layer to build on rather than hand-rolling one here.
