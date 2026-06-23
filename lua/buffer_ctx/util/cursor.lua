---@module 'buffer_ctx.util.cursor'
local M = {}
local api = vim.api

---Insert text at cursor position (inline within the current line)
---@param text string
function M.insert_text(text)
  if type(text) ~= "string" or text == "" then return end
  local win = api.nvim_get_current_win()
  if not api.nvim_win_is_valid(win) then return end
  local cursor = api.nvim_win_get_cursor(win)
  local row, col = cursor[1], cursor[2]
  local line = api.nvim_get_current_line()
  col = math.min(col, #line)
  api.nvim_set_current_line(line:sub(1, col) .. text .. line:sub(col + 1))
  api.nvim_win_set_cursor(win, { row, col + #text })
end

---Insert lines before the current cursor row
---@param lines string[]
function M.insert_lines(lines)
  if not lines or #lines == 0 then return end
  local win = api.nvim_get_current_win()
  if not api.nvim_win_is_valid(win) then return end
  local row = api.nvim_win_get_cursor(win)[1] - 1
  local bufnr = api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) then return end
  api.nvim_buf_set_lines(bufnr, row, row, false, lines)
  api.nvim_win_set_cursor(win, { row + #lines + 1, 0 })
end

return M
