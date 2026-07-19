---@module 'buffer_ctx.format.blank_lines'
---@brief Collapse consecutive blank lines down to at most one.
---@description
--- Operates on the whole buffer by default. With an explicit command range
--- (":'<,'>Format squeeze" or ":10,20Format squeeze") only that span is
--- squeezed — a leading/trailing blank line just outside the range is left
--- alone, since it isn't part of what the user selected.

local notify = require("buffer_ctx.util.notify")

local M = {}
local api = vim.api

---@param line string
---@return boolean
local function is_blank(line)
  return line:match("^%s*$") ~= nil
end

---Collapse runs of blank lines in `lines` down to at most one.
---@param lines string[]
---@return string[] result, integer removed
function M.squeeze_lines(lines)
  local out = {}
  local removed = 0
  local prev_blank = false
  for _, line in ipairs(lines) do
    if is_blank(line) and prev_blank then
      removed = removed + 1
    else
      out[#out + 1] = line
      prev_blank = is_blank(line)
    end
  end
  return out, removed
end

---Squeeze blank lines within `[start_line, end_line]` (1-based, inclusive)
---of `bufnr`, or the whole buffer when no range is given.
---@param bufnr integer
---@param start_line? integer
---@param end_line? integer
---@return integer|nil removed, string|nil err
function M.squeeze_buffer(bufnr, start_line, end_line)
  if not api.nvim_buf_is_valid(bufnr) then
    return nil, "invalid buffer"
  end

  local s = start_line or 1
  local e = end_line or api.nvim_buf_line_count(bufnr)
  if s > e then
    s, e = e, s
  end

  local lines = api.nvim_buf_get_lines(bufnr, s - 1, e, false)
  local squeezed, removed = M.squeeze_lines(lines)
  if removed > 0 then
    api.nvim_buf_set_lines(bufnr, s - 1, e, false, squeezed)
  end
  return removed
end

---@param register_fn fun(name: string, def: table): nil
function M.register_subcommands(register_fn)
  register_fn("squeeze", {
    handler = function(_, ctx)
      local bufnr = api.nvim_get_current_buf()
      local removed, err = M.squeeze_buffer(bufnr, ctx and ctx.line1, ctx and ctx.line2)
      if not removed then
        notify.error(err or "squeeze failed")
        return
      end
      if removed == 0 then
        notify.info("No extra blank lines to remove")
      else
        notify.info(string.format("Removed %d extra blank line(s)", removed))
      end
    end,
    complete = function()
      return {}
    end,
    nargs = "0",
    range = true,
    desc = "Collapse consecutive blank lines to at most one",
  })
end

return M
