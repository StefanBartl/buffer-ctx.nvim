---@module 'buffer_ctx.ops.boilerplate.templates.nvim'
local M = {}

function M.autocmd(group_name)
  group_name = group_name or "MyGroup"
  return {
    string.format('local augroup = vim.api.nvim_create_augroup("%s", { clear = true })', group_name),
    "",
    "vim.api.nvim_create_autocmd({ --[[TODO: events]] }, {",
    "  group = augroup,",
    '  pattern = "*",',
    "  callback = function()",
    "    -- TODO: Implementation",
    "  end,",
    '  desc = "TODO: Description",',
    "})",
  }
end

function M.keymap()
  return {
    'vim.keymap.set("n", "<leader>TODO", function()',
    "  -- TODO: Implementation",
    'end, { desc = "TODO: Description" })',
  }
end

return M
