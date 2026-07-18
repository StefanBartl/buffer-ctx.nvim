---@module 'buffer_ctx.config.DEFAULTS'
---@brief Pluginside default configuration for buffer-ctx.nvim.

---@type BufferCtx.Config
return {
  keymaps = {
    location_copy = "<leader>cnl",
    module_copy = "<leader>cnm",
    filepath_copy = "<leader>cnf",
  },
  commands = true,
  timestamp = {
    -- Sticky UTC: when true, every :Insert/:Copy timestamp is UTC without
    -- passing --utc each time. An explicit --utc still works (and wins).
    utc = false,
  },
  snippets = {
    -- VSCode-format snippet files loaded by :Insert snippet {name}.
    -- e.g. { vim.fn.stdpath("config") .. "/snippets/lua.json" }
    paths = {},
  },
  format = {
    enable = true,
    command = "Format",
  },
  mark = {
    enable = true,
    command = "Mark",
    keymaps = {
      toggle = "<S-m>",
      yank = "<C-p>",
    },
    sign = {
      text = "●",
      hl = "ErrorMsg",
    },
  },
  which_key = true,
}
