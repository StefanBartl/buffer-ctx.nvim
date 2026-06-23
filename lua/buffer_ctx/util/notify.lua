---@module 'buffer_ctx.util.notify'
local PREFIX = "[buffer-ctx] "
local M = {}

function M.info(msg)  vim.notify(PREFIX .. msg, vim.log.levels.INFO)  end
function M.warn(msg)  vim.notify(PREFIX .. msg, vim.log.levels.WARN)  end
function M.error(msg) vim.notify(PREFIX .. msg, vim.log.levels.ERROR) end
function M.debug(msg) vim.notify(PREFIX .. msg, vim.log.levels.DEBUG) end

return M
