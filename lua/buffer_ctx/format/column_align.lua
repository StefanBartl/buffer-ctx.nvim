---@module 'buffer_ctx.format.column_align'
---@brief Align visually selected character(s) to a target column.

local notify = require("lib.nvim.notify").create("[buffer_ctx.format.column_align]")

local M = {}

local api = vim.api

local state = { last_target_col = nil, last_fill_char = nil }

local function display_width(str)
  if type(str) ~= "string" then return 0 end
  local ok, w = pcall(vim.fn.strdisplaywidth, str)
  return ok and w or #str
end

local function get_char_at_pos(line, byte_pos)
  local char_idx = vim.str_utfindex(line, byte_pos)
  if not char_idx then
    return line:sub(byte_pos + 1, byte_pos + 1), 1
  end
  local next_byte = vim.str_byteindex(line, char_idx + 1) or #line
  local char = line:sub(byte_pos + 1, next_byte)
  return char, #char
end

local function validate_selection()
  local sp = api.nvim_buf_get_mark(0, "<")
  local ep = api.nvim_buf_get_mark(0, ">")
  if not sp or not ep or sp[1] == 0 or ep[1] == 0 then
    return false, "No valid visual selection found", nil
  end
  local mode
  if     sp[1] == ep[1]  then mode = "v"
  elseif sp[2] == ep[2]  then mode = "\22"
  else                        mode = "V"
  end
  return true, nil, {
    start_line = sp[1], end_line = ep[1],
    start_col  = sp[2], end_col  = ep[2],
    mode = mode,
  }
end

local function align_single_line(line_nr, start_col, end_col, target_col, fill_char)
  local lines = api.nvim_buf_get_lines(0, line_nr - 1, line_nr, false)
  local line  = lines and lines[1]
  if not line then return false, "Failed to read line" end

  local selected_char, char_len = get_char_at_pos(line, start_col)
  if end_col - start_col + 1 ~= char_len then
    return false, "Select exactly one character"
  end

  local current_col = start_col + 1
  if target_col <= current_col then
    return false, "Target column must be greater than current position"
  end

  local fill   = string.rep(fill_char, target_col - current_col)
  local before = line:sub(1, start_col)
  local after  = line:sub(start_col + char_len + 1)
  local ok     = pcall(api.nvim_buf_set_lines, 0, line_nr - 1, line_nr, false,
                       { before .. fill .. selected_char .. after })
  if not ok then return false, "Failed to update buffer" end

  api.nvim_win_set_cursor(0, { line_nr, target_col - 1 })
  return true, nil
end

local function align_block_lines(start_line, end_line, col, target_col, fill_char)
  local lines = api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  if not lines or #lines == 0 then return false, "Failed to read lines" end

  local new_lines = {}
  local modified  = 0
  for i, line in ipairs(lines) do
    if #line > col then
      local selected_char, char_len = get_char_at_pos(line, col)
      local current_col = col + 1
      if target_col > current_col then
        local fill   = string.rep(fill_char, target_col - current_col)
        local before = line:sub(1, col)
        local after  = line:sub(col + char_len + 1)
        new_lines[i] = before .. fill .. selected_char .. after
        modified = modified + 1
      else
        new_lines[i] = line
      end
    else
      new_lines[i] = line
    end
  end

  if modified == 0 then
    return false, "No lines modified (target column must be greater than current)"
  end

  local ok = pcall(api.nvim_buf_set_lines, 0, start_line - 1, end_line, false, new_lines)
  if not ok then return false, "Failed to update buffer" end
  return true, nil
end

---Align visually selected character(s) to `target_col`.
---@param target_col number
---@param fill_char  string|nil
function M.align_to_column(target_col, fill_char)
  if not target_col or type(target_col) ~= "number" or target_col < 1 then
    notify.error("Target column must be a positive integer")
    return
  end
  fill_char = fill_char or " "
  if type(fill_char) ~= "string" then
    notify.error("Fill character must be a string")
    return
  end
  if display_width(fill_char) ~= 1 then
    notify.error("Fill character must have display width of 1")
    return
  end

  state.last_target_col = target_col
  state.last_fill_char  = fill_char

  local valid, err, sel = validate_selection()
  if not valid or not sel then
    notify.error(err)
    return
  end

  local success, align_err
  if sel.mode == "\22" then
    success, align_err = align_block_lines(sel.start_line, sel.end_line, sel.start_col, target_col, fill_char)
  else
    success, align_err = align_single_line(sel.start_line, sel.start_col, sel.end_col, target_col, fill_char)
  end

  if not success then notify.error(align_err) return end
  notify.info(string.format("Aligned to column %d with '%s'", target_col, fill_char))
end

---Interactive alignment with prompts.
function M.align_interactive()
  local target_input = vim.fn.input("Target column: ", state.last_target_col or "")
  if target_input == "" then return end
  local target_col = tonumber(target_input)
  if not target_col or target_col < 1 then
    notify.error("Invalid column number")
    return
  end
  local fill_default = state.last_fill_char or " "
  local fill_input   = vim.fn.input("Fill character (default: space): ", fill_default)
  local fill_char    = (fill_input == "") and " " or fill_input
  M.align_to_column(target_col, fill_char)
end

---Repeat the last alignment.
function M.align_repeat()
  if not state.last_target_col then
    notify.warn("No previous alignment to repeat")
    return
  end
  M.align_to_column(state.last_target_col, state.last_fill_char)
end

return M
