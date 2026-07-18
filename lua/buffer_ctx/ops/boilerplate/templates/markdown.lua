---@module 'buffer_ctx.ops.boilerplate.templates.markdown'
---@brief Markdown boilerplate templates.

local M = {}

---YAML frontmatter block for a Markdown document
---@param title? string  document title; defaults to the buffer's filename
---@return string[]
function M.frontmatter(title)
  if not title or title == "" then
    local name = vim.api.nvim_buf_get_name(0)
    title = (name ~= "") and vim.fn.fnamemodify(name, ":t:r") or "TODO"
  end
  return {
    "---",
    string.format('title: "%s"', title),
    string.format("date: %s", os.date("%Y-%m-%d")),
    "tags: []",
    "draft: true",
    "---",
  }
end

return M
