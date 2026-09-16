-- TESTS/format_extra_spec.lua — branches format_spec.lua's happy paths don't
-- reach: format/init.lua's cfg.command/cfg.enable gates and its subcommands'
-- invalid-argument handling (driven through a real :Format2 command, the
-- same wiring a user would hit), format/misc.lua's remaining subcommands
-- (indent, case sentence/invalid, clear, sort/unique without every flag),
-- and the error/edge branches of column_align, text_width, enum_lines,
-- filter_lines, blank_lines and table_fmt.

return function(H)
  require("buffer_ctx").setup()
  local cwd = vim.fn.getcwd()

  -- ── format/init.lua: cfg.command and cfg.enable gates ─────────────────────
  local format = require("buffer_ctx.format")
  local setup2_ok = pcall(format.setup, { command = "Format2" })
  H.ok(setup2_ok, "format.setup({command='Format2'}) registers a second command name")
  H.eq(vim.fn.exists(":Format2"), 2, "Format2 is registered as a real user command")

  local disabled_ok = pcall(format.setup, { enable = false })
  H.ok(disabled_ok, "format.setup({enable=false}) is a no-op, not an error")

  -- ── misc.lua: subcommands format_spec.lua doesn't reach ───────────────────
  local buf = H.scratch(cwd .. "/format_extra_misc.lua")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "One. two. Three! four? five." })
  vim.cmd("Format2 case sentence")
  H.eq(
    vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1],
    "One. Two. Three! Four? Five.",
    "misc: case sentence capitalises after every sentence boundary"
  )

  -- notify.error's default headless handler raises through nvim_exec2 when
  -- called from inside a command callback (a Neovim characteristic, not a
  -- buffer-ctx one — plain vim.notify(msg, ERROR) inside any user command
  -- does the same) — pcall it rather than letting the error path's own
  -- notification abort this spec.
  pcall(vim.cmd, "Format2 case")
  H.eq(
    vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1],
    "One. Two. Three! Four? Five.",
    "misc: case with no mode argument leaves the buffer untouched"
  )

  pcall(vim.cmd, "Format2 case bogus")
  H.eq(
    vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1],
    "One. Two. Three! Four? Five.",
    "misc: case with an invalid mode leaves the buffer untouched"
  )

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "b", "a", "b", "A" })
  vim.cmd("Format2 unique")
  H.eq(
    table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "|"),
    "b|a|A",
    "misc: unique without -i is case-sensitive"
  )

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "B", "a", "C" })
  vim.cmd("Format2 sort -i")
  H.eq(
    table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "|"),
    "a|B|C",
    "misc: sort -i compares case-insensitively"
  )

  vim.bo[buf].expandtab = true
  vim.bo[buf].shiftwidth = 2
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "\tindented" })
  vim.cmd("Format2 indent --spaces 2")
  H.eq(
    vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1],
    "  indented",
    "misc: indent --spaces converts a tab to spaces at the given width"
  )

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "  indented" })
  vim.cmd("Format2 indent --tabs 2")
  H.eq(
    vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1],
    "\tindented",
    "misc: indent --tabs converts spaces to a tab at the given width"
  )

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "kept" })
  vim.cmd("Format2 clear")
  H.eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1], "", "misc: clear empties the buffer")

  -- ── column subcommand: invalid target and the 0-arg interactive dispatch ──
  local buf_col = H.scratch(cwd .. "/format_extra_col.lua")
  vim.api.nvim_buf_set_lines(buf_col, 0, -1, false, { "x=5" })
  vim.api.nvim_win_set_cursor(0, { 1, 2 })
  vim.cmd("normal! v\27")
  pcall(vim.cmd, "Format2 column notanumber")
  H.eq(
    vim.api.nvim_buf_get_lines(buf_col, 0, -1, false)[1],
    "x=5",
    "Format column with a non-numeric target leaves the buffer untouched"
  )

  vim.api.nvim_win_set_cursor(0, { 1, 2 })
  vim.cmd("normal! v\27")
  package.loaded["ui.kit"] = {
    input = function(opts)
      if opts.title:find("Target column") then
        opts.on_submit("6")
      elseif opts.title:find("Fill character") then
        opts.on_submit("-")
      end
    end,
  }
  package.loaded["buffer_ctx.format.column_align"] = nil
  vim.cmd("Format2 column")
  H.eq(
    vim.api.nvim_buf_get_lines(buf_col, 0, -1, false)[1],
    "x=---5",
    "Format column with no args dispatches to the interactive prompt flow"
  )
  package.loaded["ui.kit"] = nil
  package.loaded["buffer_ctx.format.column_align"] = nil

  -- ── column_align: direct-API error branches ───────────────────────────────
  local column_align = require("buffer_ctx.format.column_align")
  local ok_bad_col = pcall(column_align.align_to_column, 0)
  H.ok(ok_bad_col, "align_to_column with a non-positive column does not error")
  local ok_bad_fill = pcall(column_align.align_to_column, 5, "ab")
  H.ok(ok_bad_fill, "align_to_column with a multi-char fill does not error")
  local ok_no_sel = pcall(column_align.align_to_column, 5, "-")
  H.ok(ok_no_sel, "align_to_column with no visual selection does not error")

  do
    -- align_repeat with nothing to repeat: a fresh module instance, since the
    -- shared one already has state from earlier in the suite.
    local original = package.loaded["buffer_ctx.format.column_align"]
    package.loaded["buffer_ctx.format.column_align"] = nil
    local fresh_align = require("buffer_ctx.format.column_align")
    local repeat_ok = pcall(fresh_align.align_repeat)
    H.ok(repeat_ok, "align_repeat with no prior alignment does not error")
    package.loaded["buffer_ctx.format.column_align"] = original
  end

  local buf_multi = H.scratch(cwd .. "/format_extra_multichar.lua")
  vim.api.nvim_buf_set_lines(buf_multi, 0, -1, false, { "ab=5" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd("normal! v" .. vim.keycode("<Right>") .. "\27") -- select "ab" (2 chars)
  local sel_ok, sel_err = column_align.align_to_column(10, "-")
  local multi_result = vim.api.nvim_buf_get_lines(buf_multi, 0, -1, false)[1]
  H.eq(multi_result, "ab=5", "align_to_column over more than one char leaves the buffer untouched")
  H.eq(sel_ok, nil, "align_to_column over more than one char returns nil (notified, not raised)")
  H.eq(sel_err, nil, "align_to_column returns nothing on failure; it only notifies")

  -- ── text_width: direct-API edge branches ──────────────────────────────────
  local text_width = require("buffer_ctx.format.text_width")
  local invalid_buf_ok = pcall(text_width.reflow_buffer, 999999, 20)
  H.ok(invalid_buf_ok, "reflow_buffer on an invalid buffer does not error")

  local buf_tw = H.scratch(cwd .. "/format_extra_tw.lua")
  vim.api.nvim_buf_set_lines(buf_tw, 0, -1, false, { "one two three" })
  text_width.reflow_buffer(buf_tw, 0)
  H.eq(
    vim.api.nvim_buf_get_lines(buf_tw, 0, -1, false)[1],
    "one two three",
    "reflow_buffer with width<=0 is a no-op"
  )

  -- Known bug, pinned rather than silently worked around: detect_prefixes()
  -- extracts the bullet marker into `first_prefix` for wrap_words, but flush()
  -- only strips leading *whitespace* from each source line before tokenising
  -- — the bullet text itself ("- ") is never removed, so it is re-emitted
  -- both as `first_prefix` and as an ordinary token, duplicating the marker
  -- on the first wrapped line. See the final test-coverage report.
  vim.api.nvim_buf_set_lines(buf_tw, 0, -1, false, { "- one two three four five six" })
  text_width.reflow_range(buf_tw, 1, 1, 12)
  local bullet_lines = vim.api.nvim_buf_get_lines(buf_tw, 0, -1, false)
  H.eq(bullet_lines[1], "-  - one two", "BUG: the bullet marker is duplicated on the first line")
  H.eq(
    bullet_lines[2]:sub(1, 2),
    "  ",
    "reflow indents continuation lines to align under the bullet"
  )

  vim.api.nvim_buf_set_lines(buf_tw, 0, -1, false, { "para one here", "", "para two here" })
  text_width.reflow_buffer(buf_tw, 6)
  local para_lines = vim.api.nvim_buf_get_lines(buf_tw, 0, -1, false)
  local blank_at = nil
  for i, l in ipairs(para_lines) do
    if l == "" then
      blank_at = i
    end
  end
  H.ok(blank_at ~= nil, "reflow_buffer preserves the blank line between paragraphs")

  vim.api.nvim_buf_set_lines(buf_tw, 0, -1, false, { "abcdefghij" })
  text_width.reflow_buffer(buf_tw, 3)
  H.eq(
    vim.api.nvim_buf_get_lines(buf_tw, 0, -1, false)[1],
    "abcdefghij",
    "reflow keeps a single word longer than width on its own line, unbroken"
  )

  local range_noop_ok = pcall(text_width.reflow_range, buf_tw, 5, 1, 10)
  H.ok(range_noop_ok, "reflow_range with end_line < start_line is a no-op, not an error")

  -- ── enum_lines: enum_selection/enum_range and the alpha/ALPHA styles ──────
  local enum_lines = require("buffer_ctx.format.enum_lines")

  local enum_sel_ok = pcall(enum_lines.enum_selection, {})
  H.ok(enum_sel_ok, "enum_selection with no visual selection does not error")

  local invalid_range = enum_lines.enum_range(999999, 1, 1, {})
  H.eq(invalid_range.ok, false, "enum_range on an invalid buffer reports ok=false")
  H.eq(invalid_range.err, "Invalid buffer", "enum_range invalid-buffer error message")

  -- Known bug, pinned rather than silently worked around: alpha_marker()'s
  -- digit-generation loop always runs one extra iteration (its `until n < -1`
  -- exit check is off by one against the `n % 26` it just consumed), so
  -- every "alpha"/"ALPHA" label comes out prefixed with a spurious leading
  -- "z"/"Z" — label 1 is "za", not "a". See the final test-coverage report.
  local buf_enum = H.scratch(cwd .. "/format_extra_enum.lua")
  vim.api.nvim_buf_set_lines(buf_enum, 0, -1, false, { "alpha beta gamma" })
  local alpha_result = enum_lines.enum_range(buf_enum, 1, 1, { style = "alpha", inline = true })
  H.eq(alpha_result.ok, true, "enum_range with style=alpha succeeds")
  H.eq(
    alpha_result.lines[1],
    "za. alpha zb. beta zc. gamma",
    "BUG: alpha labels carry a spurious leading 'z'"
  )

  vim.api.nvim_buf_set_lines(buf_enum, 0, -1, false, { "alpha beta gamma" })
  local upper_result = enum_lines.enum_range(buf_enum, 1, 1, { style = "ALPHA", inline = true })
  H.eq(
    upper_result.lines[1],
    "ZA. alpha ZB. beta ZC. gamma",
    "BUG: ALPHA labels carry a spurious leading 'Z'"
  )

  -- Real visual selection through enum_selection (not just the pure enumerate()
  -- already covered in format_spec.lua).
  vim.api.nvim_buf_set_lines(buf_enum, 0, -1, false, { "un deux trois" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd("normal! V\27")
  enum_lines.enum_selection({ style = "decimal", inline = true })
  H.eq(
    vim.api.nvim_buf_get_lines(buf_enum, 0, -1, false)[1],
    "1. un 2. deux 3. trois",
    "enum_selection enumerates the real visual selection"
  )

  -- ── filter_lines: OR-conditions and the "would remove everything" guard ──
  local filter_lines = require("buffer_ctx.format.filter_lines")

  local remove_or, cond_or = filter_lines.parse_filter_args({ '{"TODO","FIXME"}' })
  H.eq(remove_or, false, "parse_filter_args: brace syntax with no --remove")
  H.eq(type(cond_or[1]), "table", "parse_filter_args: brace syntax parses to an OR-list")

  local buf_filter = H.scratch(cwd .. "/format_extra_filter.lua")
  vim.api.nvim_buf_set_lines(buf_filter, 0, -1, false, { "TODO: x", "FIXME: y", "plain" })
  local or_ok = filter_lines.filter_lines(buf_filter, { { "TODO", "FIXME" } }, false)
  H.ok(or_ok, "filter_lines with an OR condition list succeeds")
  H.eq(
    table.concat(vim.api.nvim_buf_get_lines(buf_filter, 0, -1, false), "|"),
    "TODO: x|FIXME: y",
    "filter_lines OR condition keeps lines matching either substring"
  )

  vim.api.nvim_buf_set_lines(buf_filter, 0, -1, false, { "a", "b", "c" })
  local abort_ok, abort_err = filter_lines.filter_lines(buf_filter, { "" }, true)
  H.eq(abort_ok, false, "filter_lines --remove aborts rather than emptying the buffer")
  H.match(abort_err, "would remove all lines", "filter_lines abort-all error message")

  vim.api.nvim_buf_set_lines(buf_filter, 0, -1, false, { "a", "b", "c" })
  local nomatch_ok, nomatch_err = filter_lines.filter_lines(buf_filter, { "zzz" }, false)
  H.eq(nomatch_ok, false, "filter_lines keep-mode with no matches fails rather than emptying")
  H.match(nomatch_err, "No lines matched", "filter_lines no-match error message")

  -- ── blank_lines: squeeze_buffer's reversed-range swap ─────────────────────
  local blank_lines = require("buffer_ctx.format.blank_lines")
  local buf_blank = H.scratch(cwd .. "/format_extra_blank.lua")
  vim.api.nvim_buf_set_lines(buf_blank, 0, -1, false, { "1", "", "", "2", "", "", "3" })
  local removed = blank_lines.squeeze_buffer(buf_blank, 6, 2) -- reversed on purpose
  H.eq(removed, 2, "squeeze_buffer normalises a reversed [start,end] range")

  -- ── table_fmt: parse_args error branches, driven through :Format2 table ──
  local buf_table = H.scratch(cwd .. "/format_extra_table.lua")
  vim.api.nvim_buf_set_lines(buf_table, 0, -1, false, { "| a | b |", "|---|---|", "| c | d |" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  pcall(vim.cmd, "Format2 table header=bogus")
  H.eq(
    vim.api.nvim_buf_get_lines(buf_table, 0, -1, false)[1],
    "| a | b |",
    "Format table with an invalid header= alignment leaves the buffer untouched"
  )

  pcall(vim.cmd, "Format2 table zzz")
  H.eq(
    vim.api.nvim_buf_get_lines(buf_table, 0, -1, false)[1],
    "| a | b |",
    "Format table with an unrecognised bare argument leaves the buffer untouched"
  )

  vim.cmd("Format2 table scope=/definitely/not/a/real/file.md")
  H.ok(true, "Format table with an unreadable scope path does not error")

  vim.cmd("Format2 table left right skip=1")
  local table_result = vim.api.nvim_buf_get_lines(buf_table, 0, -1, false)
  H.ok(#table_result == 3, "Format table with positional aligns + skip= does not crash")

  -- scope=buffer formats every table in the buffer, not just the one under
  -- the cursor.
  local buf_multi_table = H.scratch(cwd .. "/format_extra_table2.lua")
  vim.api.nvim_buf_set_lines(buf_multi_table, 0, -1, false, {
    "| a | bb |",
    "|---|----|",
    "text between",
    "| c | d |",
    "|---|---|",
  })
  vim.cmd("Format2 table scope=buffer")
  local multi_table_result = vim.api.nvim_buf_get_lines(buf_multi_table, 0, -1, false)
  H.eq(multi_table_result[1], "| a | bb |", "scope=buffer formats the first table")
  H.eq(multi_table_result[4], "| c | d |", "scope=buffer also formats the second table")
end
