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
---@field has_id boolean  true if the generator accepts an id/name argument

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
}

---List all registered template keys
---@return string[]
function M.list_keys()
  local keys = {}
  for _, e in ipairs(REGISTRY) do
    keys[#keys + 1] = e.key
  end
  return keys
end

---Generate template lines for the given key
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
      local result
      if entry.has_id and name and name ~= "" then
        result = gen(name)
      else
        result = gen()
      end
      return result
    end
  end
  return nil, "unknown template: " .. tostring(key)
end

return M
