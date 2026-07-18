-- docs/TESTS/format_spec.lua — buffer_ctx.format submodules.
-- Requires buffer_ctx.setup() to have registered :Format for the misc.lua
-- subcommand coverage (trim/sort/unique/case/indent); the other submodules
-- are exercised directly via their Lua API.

return function(H)
  require("buffer_ctx").setup()

  local filter_lines = require("buffer_ctx.format.filter_lines")
  local enum_lines = require("buffer_ctx.format.enum_lines")
  local table_fmt = require("buffer_ctx.format.table_fmt")
  local column_align = require("buffer_ctx.format.column_align")
  local text_width = require("buffer_ctx.format.text_width")

  -- filter_lines: arg parsing
  local remove1, cond1 = filter_lines.parse_filter_args({ "TODO" })
  H.eq(remove1, false, "filter parse_args: no --remove flag")
  H.eq(cond1[1], "TODO", "filter parse_args: condition captured")

  local remove2, cond2 = filter_lines.parse_filter_args({ "--remove", "FIXME" })
  H.eq(remove2, true, "filter parse_args: --remove flag")
  H.eq(cond2[1], "FIXME", "filter parse_args: condition after flag")

  -- filter_lines: keep mode
  local buf_keep = H.scratch(vim.fn.getcwd() .. "/filter_keep.lua")
  vim.api.nvim_buf_set_lines(buf_keep, 0, -1, false, { "TODO: x", "normal", "TODO: y" })
  local ok_keep, err_keep = filter_lines.filter_lines(buf_keep, { "TODO" }, false)
  H.ok(ok_keep, "filter keep mode succeeds")
  H.eq(err_keep, nil, "filter keep mode has no error")
  H.eq(
    table.concat(vim.api.nvim_buf_get_lines(buf_keep, 0, -1, false), "|"),
    "TODO: x|TODO: y",
    "filter keep mode result"
  )

  -- filter_lines: remove mode
  local buf_remove = H.scratch(vim.fn.getcwd() .. "/filter_remove.lua")
  vim.api.nvim_buf_set_lines(buf_remove, 0, -1, false, { "TODO: x", "normal", "TODO: y" })
  local ok_remove = filter_lines.filter_lines(buf_remove, { "TODO" }, true)
  H.ok(ok_remove, "filter remove mode succeeds")
  H.eq(
    table.concat(vim.api.nvim_buf_get_lines(buf_remove, 0, -1, false), "|"),
    "normal",
    "filter remove mode result"
  )

  -- filter_lines: guards
  local ok_invalid, err_invalid = filter_lines.filter_lines(999999, { "x" }, false)
  H.eq(ok_invalid, false, "filter rejects invalid buffer")
  H.eq(err_invalid, "Invalid buffer", "filter invalid buffer error message")

  local ok_noconds, err_noconds = filter_lines.filter_lines(buf_keep, {}, false)
  H.eq(ok_noconds, false, "filter rejects empty conditions")
  H.eq(err_noconds, "No conditions provided", "filter no-conditions error message")

  -- enum_lines: pure enumerate()
  local dec = enum_lines.enumerate({ "foo bar" }, { style = "decimal" })
  H.ok(dec.ok, "enum decimal ok")
  H.eq(dec.lines[1], "1. foo 2. bar", "enum decimal single-line inline result")
  H.eq(dec.count, 2, "enum decimal token count")

  local rom = enum_lines.enumerate({ "foo", "bar" }, { style = "roman" })
  H.ok(rom.ok, "enum roman ok")
  H.eq(rom.lines[1], "i. foo", "enum roman multiline first")
  H.eq(rom.lines[2], "ii. bar", "enum roman multiline second")

  local empty = enum_lines.enumerate({ "" }, {})
  H.eq(empty.ok, false, "enum empty selection fails")
  H.eq(empty.err, "No tokens found in selection", "enum empty selection error message")

  -- table_fmt: alignment widens ragged columns and keeps them ok=true, err=nil
  local buf_table = H.scratch(vim.fn.getcwd() .. "/table_fmt_test.lua")
  vim.api.nvim_buf_set_lines(buf_table, 0, -1, false, { "| a | b |", "|---|-----|", "| ccc | d |" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local tok, terr = table_fmt.format_table_at_cursor(buf_table, {})
  H.ok(tok, "table_fmt succeeds")
  H.eq(
    terr,
    nil,
    "table_fmt reports no error on success (regression: used to always report 'Failed to update buffer')"
  )
  local table_result = vim.api.nvim_buf_get_lines(buf_table, 0, -1, false)
  H.eq(table_result[1], "|  a  | b |", "table_fmt aligns header row")
  H.eq(table_result[2], "|-----|---|", "table_fmt aligns separator row")
  H.eq(table_result[3], "| ccc | d |", "table_fmt aligns data row")

  -- column_align: pads selected char to target column
  local buf_col = H.scratch(vim.fn.getcwd() .. "/column_align_test.lua")
  vim.api.nvim_buf_set_lines(buf_col, 0, -1, false, { "x=5" })
  vim.api.nvim_buf_set_mark(buf_col, "<", 1, 2, {})
  vim.api.nvim_buf_set_mark(buf_col, ">", 1, 2, {})
  column_align.align_to_column(10, "-")
  H.eq(
    vim.api.nvim_buf_get_lines(buf_col, 0, -1, false)[1],
    "x=-------5",
    "column_align pads to target column"
  )

  -- text_width: reflows long line into width-bounded chunks (regression: used to crash)
  local buf_tw = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf_tw, 0, -1, false, { "one two three four five" })
  local reflow_ok = pcall(text_width.reflow_buffer, buf_tw, 10)
  H.ok(reflow_ok, "text_width.reflow_buffer does not crash")
  H.eq(
    table.concat(vim.api.nvim_buf_get_lines(buf_tw, 0, -1, false), "|"),
    "one two|three four|five",
    "text_width reflows to width-bounded lines"
  )

  -- misc.lua subcommands, exercised through :Format (registered by setup() above)
  local buf_misc = H.scratch(vim.fn.getcwd() .. "/misc_test.lua")
  vim.api.nvim_buf_set_lines(buf_misc, 0, -1, false, { "b  ", "a  ", "c  " })
  vim.cmd("Format trim")
  H.eq(
    table.concat(vim.api.nvim_buf_get_lines(buf_misc, 0, -1, false), "|"),
    "b|a|c",
    "misc: trim removes trailing whitespace"
  )
  vim.cmd("Format sort")
  H.eq(
    table.concat(vim.api.nvim_buf_get_lines(buf_misc, 0, -1, false), "|"),
    "a|b|c",
    "misc: sort orders lines"
  )

  vim.api.nvim_buf_set_lines(buf_misc, 0, -1, false, { "b", "a", "b", "A" })
  vim.cmd("Format unique -i")
  H.eq(
    table.concat(vim.api.nvim_buf_get_lines(buf_misc, 0, -1, false), "|"),
    "b|a",
    "misc: unique -i drops case-insensitive dupes"
  )

  vim.api.nvim_buf_set_lines(buf_misc, 0, -1, false, { "hello world" })
  vim.cmd("Format case upper")
  H.eq(vim.api.nvim_buf_get_lines(buf_misc, 0, -1, false)[1], "HELLO WORLD", "misc: case upper")
end
