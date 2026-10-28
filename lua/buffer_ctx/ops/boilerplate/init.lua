---@module 'buffer_ctx.ops.boilerplate'
--- Template registry; sub-modules under templates/ are required lazily
--- per key so unused templates are never loaded.
---@see buffer_ctx.ops.boilerplate.templates.lua

local M = {}

---@class BufferCtx.Boilerplate.Entry
---@field key string
---@field module string   template sub-module name
---@field fn string       function name within that module
---@field desc string
---@field has_id boolean         true if the generator accepts an id/name argument
---@field is_interactive? boolean true if the generator prompts interactively
---                               (only guard-clause so far, in a kit.form):
---                               its generator is `fn(cb)`, asynchronous, and
---                               `M.get_async` is the call for it; `M.get`
---                               refuses it. A caller that must not pop a
---                               prompt as a side effect (e.g. a live-preview
---                               pane on cursor movement) checks this first
---                               and skips/placeholders

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
    is_interactive = true, -- guard_interactive(cb) asks in a kit.form: asynchronous, use `M.get_async`
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

---True when `key`'s generator prompts interactively (currently only guard-clause, in a kit.form). Its
---generator is asynchronous: ask `M.get_async`. This is also for a caller that must not trigger a prompt as a side
---effect of something other than an explicit user selection (e.g. a live-preview pane on cursor movement), which
---should check this first and skip/placeholder.
---@param key string
---@return boolean
function M.is_interactive(key)
  for _, e in ipairs(REGISTRY) do
    if e.key == key then
      return e.is_interactive == true
    end
  end
  return false
end

---Generate template lines for the given key.
---@param key string
---@param name? string  optional id/name arg passed to the generator
---@return string[]|nil lines, string|nil err
function M.get(key, name)
  for _, entry in ipairs(REGISTRY) do
    if entry.key == key then
      local mod_path = "buffer_ctx.ops.boilerplate.templates." .. entry.module
      local ok, tmod = pcall(require, mod_path)
      if not ok then
        return nil, "could not load template module: " .. mod_path
      end
      local gen = tmod[entry.fn]
      if type(gen) ~= "function" then
        return nil, "template function not found: " .. entry.fn
      end
      if entry.is_interactive then
        return nil, "interactive template '" .. key .. "': use boilerplate.get_async"
      end

      local lines
      if entry.has_id and name and name ~= "" then
        lines = gen(name)
      else
        lines = gen()
      end
      return lines, nil
    end
  end
  return nil, "unknown template: " .. tostring(key)
end

---Generate template lines, asking the user when the template is interactive. `cb(lines, err, cancelled)` is called once:
---`cancelled` is true when an interactive generator returned nil because the user dismissed the prompt, not because
---generation failed. A template that is not interactive answers at once (inside this call).
---@param key string
---@param name? string
---@param cb fun(lines: string[]|nil, err: string|nil, cancelled: boolean|nil)
function M.get_async(key, name, cb)
  for _, entry in ipairs(REGISTRY) do
    if entry.key == key and entry.is_interactive then
      local ok, tmod = pcall(require, "buffer_ctx.ops.boilerplate.templates." .. entry.module)
      local gen = ok and tmod[entry.fn] or nil
      if type(gen) ~= "function" then
        cb(nil, "template function not found: " .. entry.fn)
        return
      end
      gen(function(lines)
        if lines == nil then
          cb(nil, nil, true)
        else
          cb(lines, nil)
        end
      end)
      return
    end
  end
  local lines, err = M.get(key, name)
  cb(lines, err)
end

return M
