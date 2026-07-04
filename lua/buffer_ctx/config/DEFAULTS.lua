---@module 'buffer_ctx.config.DEFAULTS'
---@brief Pluginside default configuration for buffer-ctx.nvim.

---@type BufferCtx.Config
return {
  keymaps = {
    location_copy = "<leader>cnl",
    module_copy   = "<leader>cnm",
    filepath_copy = "<leader>cnf",
  },
  commands = true,
  format = {
    enable  = true,
    command = "Format",
  },
  mark = {
    enable  = true,
    command = "Mark",
    keymaps = {
      toggle = "<S-m>",
      yank   = "<C-p>",
    },
    sign = {
      text = "●",
      hl   = "ErrorMsg",
    },
  },
  which_key = true,
}
