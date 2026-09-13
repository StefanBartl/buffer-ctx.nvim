# buffer-ctx.nvim - Roadmap

---

## Known issues

_None currently open._

## Fixed

- ~~**`:Mark` drifts on edit**~~ — marks were keyed by raw line number, not
  extmark ID, so inserting/deleting lines above a mark desynced the visual
  indicator from the data and `:Mark yank` copied the wrong lines. Marks are
  now anchored by extmark ID and resolved to their current line on every
  read. Rationale and implementation notes:
  [anchor-stable-marks.md](anchor-stable-marks.md).

