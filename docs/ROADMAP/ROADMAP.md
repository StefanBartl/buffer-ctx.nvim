# buffer-ctx.nvim - Roadmap

---

## Known issues

- **`:Mark` drifts on edit** — marks are keyed by raw line number, not
  extmark ID, so inserting/deleting lines above a mark desyncs the visual
  indicator from the data; `:Mark yank` then copies the wrong lines. Bug +
  fix proposal: [anchor-stable-marks.md](anchor-stable-marks.md).

