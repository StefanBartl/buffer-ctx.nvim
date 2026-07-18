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
    vim.health.ok(
      "plugin loaded (vim.g.loaded_buffer_ctx = " .. tostring(vim.g.loaded_buffer_ctx) .. ")"
    )
  else
    vim.health.warn("plugin guard not set — call require('buffer_ctx').setup()")
  end

  local notify_ok, notify_mod = pcall(require, "buffer_ctx.util.notify")
  if notify_ok and notify_mod.using_lib() then
    vim.health.ok("lib.nvim detected — using lib.nvim.notify (optional dependency)")
  else
    vim.health.info("lib.nvim not found — using plain vim.notify (optional dependency)")
  end

  local map_ok, map_mod = pcall(require, "buffer_ctx.util.map")
  if map_ok and map_mod.using_lib() then
    vim.health.ok("lib.nvim detected — using lib.nvim.map for keymaps (optional dependency)")
  else
    vim.health.info("lib.nvim not found — using plain vim.keymap.set (optional dependency)")
  end

  local wk_ok, wk_mod = pcall(require, "buffer_ctx.bindings.which_key")
  if wk_ok and wk_mod.available() then
    vim.health.ok("which-key detected — <leader>cn group label registered (optional dependency)")
  else
    vim.health.info(
      "which-key not found — keymaps still work, no group label (optional dependency)"
    )
  end

  local bindings_ok = pcall(require, "buffer_ctx.bindings")
  if bindings_ok then
    vim.health.ok("buffer_ctx.bindings loaded")
  else
    vim.health.warn("buffer_ctx.bindings failed to load")
  end

  -- Format subsystem
  vim.health.start("buffer_ctx.format")

  local cfg_ok, cfg_mod = pcall(require, "buffer_ctx.config")
  local format_enabled = false
  if cfg_ok then
    local cfg = cfg_mod.get()
    local fmt = cfg.format
    format_enabled = fmt ~= false and (fmt == true or fmt == nil or fmt.enable ~= false)
  end

  if format_enabled then
    vim.health.ok("format subsystem enabled")
  else
    vim.health.info("format subsystem disabled (format = false or enable = false in opts)")
    return
  end

  local cmd_exists = vim.fn.exists(":Format") == 2
  if cmd_exists then
    vim.health.ok(":Format command registered")
  else
    vim.health.warn(":Format command not found — call setup() first")
  end

  local modules = {
    { name = "column_align", mod = "buffer_ctx.format.column_align" },
    { name = "table_fmt", mod = "buffer_ctx.format.table_fmt" },
    { name = "text_width", mod = "buffer_ctx.format.text_width" },
    { name = "filter_lines", mod = "buffer_ctx.format.filter_lines" },
    { name = "enum_lines", mod = "buffer_ctx.format.enum_lines" },
    { name = "misc", mod = "buffer_ctx.format.misc" },
  }
  for _, entry in ipairs(modules) do
    local ok = pcall(require, entry.mod)
    if ok then
      vim.health.ok(entry.name .. " loaded")
    else
      vim.health.warn(entry.name .. " failed to load (" .. entry.mod .. ")")
    end
  end

  -- Mark subsystem
  vim.health.start("buffer_ctx.mark")

  local mark_enabled = false
  if cfg_ok then
    local cfg = cfg_mod.get()
    local mk = cfg.mark
    mark_enabled = mk ~= false and (mk == true or mk == nil or mk.enable ~= false)
  end

  if mark_enabled then
    vim.health.ok("mark subsystem enabled")
  else
    vim.health.info("mark subsystem disabled (mark = false in opts)")
    return
  end

  if vim.fn.exists(":Mark") == 2 then
    vim.health.ok(":Mark command registered")
  else
    vim.health.warn(":Mark command not found — call setup() first")
  end

  if vim.fn.exists(":MarkLineToggle") == 2 then
    vim.health.ok(":MarkLineToggle compat command registered")
  else
    vim.health.warn(":MarkLineToggle compat command not found")
  end

  local mark_ok = pcall(require, "buffer_ctx.mark")
  if mark_ok then
    vim.health.ok("buffer_ctx.mark loaded")
  else
    vim.health.warn("buffer_ctx.mark failed to load")
  end
end

return M
