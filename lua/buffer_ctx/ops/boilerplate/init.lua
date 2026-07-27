---@module 'buffer_ctx.ops.boilerplate'
---@brief Template registry; sub-modules under templates/ are required lazily
--- per key so unused templates are never loaded.
---@see buffer_ctx.ops.boilerplate.templates.lua and its siblings for the
--- template implementations REGISTRY dispatches to

local M = {}

---@class BufferCtx.Boilerplate.Entry
---@field key string
---@field module string   template sub-module name
---@field fn string       function name within that module
---@field desc string
---@field has_id boolean    true if the generator accepts an id/name argument
---@field is_async? boolean true if the generator is `gen(callback)` /
---                         `gen(name, callback)` instead of returning lines
---                         directly (only guard-clause so far, which prompts
---                         via kit.form)

local REGISTRY = {
  {
    key = "lua-module",
    module = "lua",
    fn = "module",
    desc = "Lua module skeleton",
    has_id = false,
  },
  {
    key = "lua-class",
    module = "lua",
    fn = "class",
    desc = "Lua OOP class skeleton",
    has_id = true,
  },
  {
    key = "lua-function",
    module = "lua",
    fn = "func",
    desc = "Annotated function stub",
    has_id = false,
  },
  {
    key = "nvim-autocmd",
    module = "nvim",
    fn = "autocmd",
    desc = "nvim_create_autocmd block",
    has_id = true,
  },
  {
    key = "nvim-keymap",
    module = "nvim",
    fn = "keymap",
    desc = "vim.keymap.set stub",
    has_id = false,
  },
  {
    key = "guard-clause",
    module = "guard",
    fn = "guard_interactive",
    desc = "Guard clause pattern",
    has_id = false,
    is_async = true, -- guard_interactive(callback) prompts via kit.form
  },
  {
    key = "html-figure",
    module = "html",
    fn = "figure",
    desc = "HTML <figure> block",
    has_id = true,
  },
  {
    key = "html-code",
    module = "html",
    fn = "code",
    desc = "HTML code listing",
    has_id = true,
  },
  {
    key = "html-quote",
    module = "html",
    fn = "quote",
    desc = "HTML blockquote",
    has_id = true,
  },
  {
    key = "html-formula-table",
    module = "html",
    fn = "formula_table",
    desc = "HTML formula table",
    has_id = true,
  },
  {
    key = "html-aside",
    module = "html",
    fn = "aside",
    desc = "HTML <aside> block",
    has_id = true,
  },
  {
    key = "html-pagination",
    module = "html",
    fn = "pagination",
    desc = "HTML pagination nav",
    has_id = true,
  },
  {
    key = "html-accordion",
    module = "html",
    fn = "accordion",
    desc = "HTML <details> accordion",
    has_id = true,
  },
  {
    key = "html-table",
    module = "html",
    fn = "table",
    desc = "HTML <table> with thead + 3x3 body",
    has_id = true,
  },
  {
    key = "html-section",
    module = "html",
    fn = "section",
    desc = "HTML <section> with h2 + p",
    has_id = true,
  },
  {
    key = "lua-test",
    module = "lua",
    fn = "test",
    desc = "busted test stub (describe/it/assert)",
    has_id = true,
  },
  {
    key = "lua-enum",
    module = "lua",
    fn = "enum",
    desc = "Enum table + ---@alias block",
    has_id = true,
  },
  {
    key = "md-frontmatter",
    module = "markdown",
    fn = "frontmatter",
    desc = "YAML frontmatter block",
    has_id = true,
  },
}

---Descriptions keyed by template name, for pickers and vim.ui.select
---@return table<string, string>
function M.describe()
  local out = {}
  for _, e in ipairs(REGISTRY) do
    out[e.key] = e.desc
  end
  return out
end

---List all registered template keys
---@return string[]
function M.list_keys()
  local keys = {}
  for _, e in ipairs(REGISTRY) do
    keys[#keys + 1] = e.key
  end
  return keys
end

---True when `key`'s generator is async (`gen(callback)`/`gen(name, callback)`
---and prompts interactively, e.g. guard-clause via kit.form) rather than
---returning lines directly. Callers that can't use the callback form of
---`M.get` (e.g. a live-preview pane that must not pop a prompt as a side
---effect of cursor movement) should check this first and skip/placeholder
---instead of calling `M.get` with no callback.
---@param key string
---@return boolean
function M.is_async(key)
  for _, e in ipairs(REGISTRY) do
    if e.key == key then
      return e.is_async == true
    end
  end
  return false
end

---Generate template lines for the given key. Synchronous entries (all but
---guard-clause) return `lines` directly and, if `callback` was given, also
---invoke it with the same result -- so every call site can use the callback
---form uniformly without branching on `entry.is_async`. Async entries
---(currently only guard-clause, which prompts via kit.form) never return
---`lines` directly -- the result only ever reaches the caller through
---`callback`, so passing no callback for those silently drops the result.
---@param key string
---@param name? string  optional id/name arg passed to the generator
---@param callback? fun(lines: string[]|nil, err: string|nil)
---@return string[]|nil lines, string|nil err  # nil,nil for async entries
function M.get(key, name, callback)
  for _, entry in ipairs(REGISTRY) do
    if entry.key == key then
      local mod_path = "buffer_ctx.ops.boilerplate.templates." .. entry.module
      local ok, tmod = pcall(require, mod_path)
      if not ok then
        local err = "could not load template module: " .. mod_path
        if callback then callback(nil, err) end
        return nil, err
      end
      local gen = tmod[entry.fn]
      if type(gen) ~= "function" then
        local err = "template function not found: " .. entry.fn
        if callback then callback(nil, err) end
        return nil, err
      end

      if entry.is_async then
        local cb = callback or function() end
        if entry.has_id and name and name ~= "" then
          gen(name, cb)
        else
          gen(cb)
        end
        return nil, nil
      end

      local result
      if entry.has_id and name and name ~= "" then
        result = gen(name)
      else
        result = gen()
      end
      if callback then
        callback(result, nil)
      end
      return result
    end
  end
  local err = "unknown template: " .. tostring(key)
  if callback then callback(nil, err) end
  return nil, err
end

return M
