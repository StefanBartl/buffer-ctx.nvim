-- luacheck configuration for buffer-ctx.nvim
std = "luajit"
cache = true

-- Neovim injects `vim` globally; it is read-only from the plugin's side.
read_globals = { "vim" }

-- The spec files receive the harness as a parameter, nothing global.
files["docs/TESTS/"] = {
  read_globals = { "vim" },
}

ignore = {
  "212/self", -- unused self in method-style definitions
  "631",      -- line length: enforced by stylua's column width instead
}

exclude_files = {
  ".luacheckrc",
}
