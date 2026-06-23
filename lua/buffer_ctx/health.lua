---@module 'buffer_ctx.health'
local M = {}

function M.check()
  vim.health.start("buffer_ctx")

  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim >= 0.9")
  else
    vim.health.warn("Neovim 0.9+ recommended")
  end

  if vim.uv or vim.loop then
    vim.health.ok("libuv available (" .. (vim.uv and "vim.uv" or "vim.loop") .. ")")
  else
    vim.health.warn("libuv not found")
  end

  if type(vim.fn.setreg) == "function" then
    vim.health.ok("vim.fn.setreg available (clipboard)")
  else
    vim.health.warn("vim.fn.setreg unavailable — clipboard ops will fail")
  end

  if vim.g.loaded_buffer_ctx then
    vim.health.ok("plugin loaded (vim.g.loaded_buffer_ctx = " .. tostring(vim.g.loaded_buffer_ctx) .. ")")
  else
    vim.health.warn("plugin guard not set — call require('buffer_ctx').setup()")
  end
end

return M
