-- luacheck configuration for buffer-ctx.nvim
std = "luajit"
cache = true

-- Neovim injects `vim` globally. It must be a writable global, not a
-- read_global: plugins legitimately assign to vim.g.*, vim.bo.* and vim.opt.*,
-- and read_globals would flag every one of those as "setting read-only field".
globals = { "vim" }

ignore = {
  "212/self", -- unused self in method-style definitions
  "631",      -- line length: enforced by stylua's column width instead
}

exclude_files = {
  ".luacheckrc",
}
