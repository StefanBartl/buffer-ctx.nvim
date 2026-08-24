# Configuration

```lua
require("buffer_ctx").setup({
  commands = true,           -- register :Insert and :Copy
  keymaps = {
    location_copy = "<leader>cnl",   -- copy path:line
    module_copy   = "<leader>cnm",   -- copy Lua module path
    filepath_copy = "<leader>cnf",   -- copy relative filepath
  },
  -- keymaps = false  to disable all keymaps
  which_key = true,          -- label <leader>cn group when which-key is installed
  timestamp = {
    utc = false,             -- true → every timestamp is UTC without --utc
  },
  snippets = {
    paths = {},              -- VSCode-format snippet files for :Insert snippet
    -- e.g. { vim.fn.stdpath("config") .. "/snippets/lua.json" }
  },
  format = {
    enable  = true,          -- register :Format (default true)
    command = "Format",      -- command name
  },
  -- format = false   to disable :Format entirely
  mark = {
    enable  = true,          -- register :Mark (default true)
    command = "Mark",        -- command name
    keymaps = {
      toggle = "<S-m>",      -- toggle mark on current line; a count marks N lines
      yank   = "<C-p>",      -- yank all marked lines
      -- clear = "<leader>mc",  -- remove every mark in the buffer (unset by default)
    },
    -- Appearance of the `default` category.
    sign = {
      text = "●",            -- sign column / extmark glyph
      hl   = "ErrorMsg",     -- highlight group
    },
    -- Extra named appearances beyond `default`, so marks can mean different
    -- things in the same buffer. `:Mark toggle todo` marks in that category;
    -- `:Mark yank todo` / `:Mark clear todo` filter by it.
    categories = {
      -- { name = "todo", text = "●", hl = "WarningMsg" },
      -- { name = "done", text = "●", hl = "DiagnosticOk" },
    },
  },
  -- mark = false   to disable :Mark entirely
})
```

See [Keymaps & commands cheatsheet](BINDINGS.md) for how these options map to the keymaps and user commands they control.
