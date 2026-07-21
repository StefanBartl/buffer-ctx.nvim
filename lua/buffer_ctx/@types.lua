---@meta
---@module 'buffer_ctx.@types'
--- Central type declarations shared across the buffer_ctx plugin.
--- Config classes, aliases and per-domain option shapes referenced by name
--- from every other module live here.

---@alias BufferCtx.Sink "cursor" | "clip"

---@alias BufferCtx.FilepathMode "cwd" | "abs" | "nvim"
---@alias BufferCtx.FilepathFormat "lua" | "unix" | "win" | "system"

---@class BufferCtx.FilepathOpts
---@field mode BufferCtx.FilepathMode
---@field format BufferCtx.FilepathFormat
---@field depth integer|nil

---@alias BufferCtx.ModuleStyle "require" | "lua_ls" | "luals" | "js" | "c" | "generic"

---@alias BufferCtx.TimestampFormat "iso" | "iso-date" | "iso-time" | "unix" | "human" | "short" | "log" | "filename" | "long" | "weekday" | "time" | "12h" | "rfc2822"

---@alias BufferCtx.UUIDFormat "standard" | "compact" | "upper" | "braced"

---@alias BufferCtx.AnnotationType "module" | "class" | "field" | "param" | "return" | "function" | "alias" | "overload" | "diagnostic" | "deprecated"

---@alias BufferCtx.LocationMode "cwd" | "abs" | "lua"

---@alias BufferCtx.GitMode "hash" | "short" | "branch" | "tag"

---@class BufferCtx.TimestampConfig
---@field utc? boolean   Emit every timestamp in UTC without --utc (default false)

---@class BufferCtx.SnippetConfig
---@field paths? string[]   VSCode-format snippet files for :Insert snippet

---@class BufferCtx.KeymapConfig
---@field location_copy? string   keymap to copy path:line  (default "<leader>cnl")
---@field module_copy? string     keymap to copy module path (default "<leader>cnm")
---@field filepath_copy? string   keymap to copy relative filepath (default "<leader>cnf")

---@class BufferCtx.MarkKeymaps
---@field toggle? string   keymap to toggle mark on current line, or N lines with a count (default "<S-m>")
---@field yank?   string   keymap to yank all marked lines       (default "<C-p>")
---@field clear?  string   keymap to remove every mark in the buffer (unset by default)

---@class BufferCtx.MarkSign
---@field text? string   Sign/virt-text glyph (default "●")
---@field hl?   string   Highlight group      (default "ErrorMsg")

---One mark category: a named appearance a mark can be placed in.
---@class BufferCtx.MarkCategory
---@field name  string   Category name, as typed after `:Mark toggle`
---@field text? string   Glyph      (defaults to the `default` category's)
---@field hl?   string   Highlight  (defaults to the `default` category's)

---@class BufferCtx.MarkConfig
---@field enable?  boolean            Register :Mark command (default true)
---@field command? string             Command name           (default "Mark")
---@field keymaps? BufferCtx.MarkKeymaps | false
---@field sign?    BufferCtx.MarkSign  Appearance of the `default` category
---@field categories? BufferCtx.MarkCategory[]  Extra named appearances beyond `default`

---@class BufferCtx.FormatConfig
---@field enable?  boolean   Register :Format command (default true)
---@field command? string   Command name              (default "Format")

---@class BufferCtx.Config
---@field keymaps?   BufferCtx.KeymapConfig | boolean
---@field commands?  boolean
---@field timestamp? BufferCtx.TimestampConfig
---@field snippets?  BufferCtx.SnippetConfig
---@field format?    BufferCtx.FormatConfig | boolean
---@field mark?      BufferCtx.MarkConfig | boolean
---@field which_key? boolean   Label configured keymaps in which-key when installed (default true)
