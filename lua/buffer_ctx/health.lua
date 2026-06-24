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
    { name = "table_fmt",    mod = "buffer_ctx.format.table_fmt"    },
    { name = "text_width",   mod = "buffer_ctx.format.text_width"   },
    { name = "filter_lines", mod = "buffer_ctx.format.filter_lines" },
    { name = "enum_lines",   mod = "buffer_ctx.format.enum_lines"   },
    { name = "misc",         mod = "buffer_ctx.format.misc"         },
  }
  for _, entry in ipairs(modules) do
    local ok = pcall(require, entry.mod)
    if ok then
      vim.health.ok(entry.name .. " loaded")
    else
      vim.health.warn(entry.name .. " failed to load (" .. entry.mod .. ")")
    end
  end
end

return M
