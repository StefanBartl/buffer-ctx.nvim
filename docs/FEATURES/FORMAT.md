# Format

The `:Format` command tree — buffer and visual-selection formatting
operations. Independent of `:Insert`/`:Copy`: nothing here reads context
about the buffer's identity, only its text. Registered as its own
top-level command via `lib.nvim.bindings.usercmd.composer`, and can be disabled
entirely with `opts.format = false`.

## Column alignment

Aligns a char- or blockwise visual selection to a target column, padding
with a chosen fill character (space by default). Deliberately refuses a
linewise selection: column alignment is about columns, and a linewise
selection's marks run from column 0 to `MAXCOL`, which carries no usable
geometry to align against.

- **Module:** `format/column_align.lua`
- **Usercmds:** `:Format column <N> [fill]` (visual: charwise/blockwise only)

## Markdown table formatting

Formats one or more Markdown tables in the buffer or selection: column
widths, per-column alignment (`header=`/`cell=` for left/center/right),
which columns to skip, and scope (whole buffer vs. selection).

- **Module:** `format/table_fmt.lua`
- **Usercmds:** `:Format table [ALIGN] [header=] [cell=] [skip=] [scope=]`

## Text width reflow

Sets `textwidth` to a given number (or `max`, the current window width)
and reflows the buffer to it in one step, instead of setting the option
and running the reflow separately.

- **Module:** `format/text_width.lua`
- **Usercmds:** `:Format textwidth <N|max>`

## Line filtering

Keeps or removes lines matching one or more patterns, with a
`--remove`/`-r` flag to invert from "keep matching" to "drop matching".
Reports the before/after line count so a filter's effect is visible
immediately.

- **Module:** `format/filter_lines.lua`
- **Usercmds:** `:Format filter [--remove] <pattern> ...`

## Line enumeration

Numbers the tokens in a visual selection using a chosen style (decimal,
alpha, ALPHA, roman, ROMAN), separator, start value, and inline-vs-own-line
placement.

- **Module:** `format/enum_lines.lua`
- **Usercmds:** `:Format enum [STYLE] [sep=] [start=] [inline=true|false]`
  (visual)

## Blank-line squeeze

Collapses runs of consecutive blank lines down to at most one, either
across the whole buffer or within a given range (`:'<,'>Format squeeze`
or `:L1,L2Format squeeze`).

- **Module:** `format/blank_lines.lua`
- **Usercmds:** `:Format squeeze` (range-aware)

## Line utilities

Six small, argument-light buffer-wide operations grouped together
because each does exactly one thing to every line in the buffer: `trim`
(strip trailing whitespace), `sort` (with `-r` reverse, `-i`
case-insensitive, `-n` numeric-aware flags), `unique` (drop duplicate
lines, `-i` for case-insensitive comparison), `case` (`upper`/`lower`/
`title`/`sentence`), `indent` (normalize to spaces or tabs at a given
width), and `clear` (empty the buffer).

- **Module:** `format/misc.lua`
- **Usercmds:** `:Format trim`, `:Format sort [-r] [-i] [-n]`,
  `:Format unique [-i]`, `:Format case <mode>`,
  `:Format indent [--spaces|--tabs] [N]`, `:Format clear`

`case`'s `sentence` mode is implemented locally rather than delegating to
lib.nvim's case transform, since lib.nvim's own `sentence` mode only
capitalizes the very first letter of the buffer — this module's version
handles multiple sentence boundaries (`[.!?]\s+`) within the same buffer.
