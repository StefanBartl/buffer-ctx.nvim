---@module 'buffer_ctx.@types'

---@alias BufferCtx.Sink "cursor" | "clip"

---@alias BufferCtx.FilepathMode "cwd" | "abs" | "nvim"
---@alias BufferCtx.FilepathFormat "lua" | "unix" | "win" | "system"

---@class BufferCtx.FilepathOpts
---@field mode BufferCtx.FilepathMode
---@field format BufferCtx.FilepathFormat
---@field depth integer|nil

---@alias BufferCtx.ModuleStyle "require" | "lua_ls" | "luals" | "js" | "c" | "generic"

---@alias BufferCtx.TimestampFormat "iso" | "iso-date" | "iso-time" | "unix" | "human" | "short" | "log" | "filename"

---@alias BufferCtx.UUIDFormat "standard" | "compact" | "upper" | "braced"

---@alias BufferCtx.AnnotationType "module" | "class" | "field" | "param" | "return" | "function" | "alias"

---@alias BufferCtx.LocationMode "cwd" | "abs" | "lua"

---@class BufferCtx.KeymapConfig
---@field location_copy? string   keymap to copy path:line  (default "<leader>cnl")
---@field module_copy? string     keymap to copy module path (default "<leader>cnm")
---@field filepath_copy? string   keymap to copy relative filepath (default "<leader>cnf")

---@class BufferCtx.Config
---@field keymaps? BufferCtx.KeymapConfig | boolean
---@field commands? boolean
