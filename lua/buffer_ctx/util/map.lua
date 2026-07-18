---@module 'buffer_ctx.util.map'
---@brief Keymap wrapper; upgrades to lib.nvim's map helper when lib.nvim is
--- installed. Soft dependency only: falls back to plain vim.keymap.set when
--- lib.nvim is absent, so the plugin stays standalone.
---@see buffer_ctx.util.notify for the same soft-dependency pattern

local M = {}

local ok_lib_map, lib_map = pcall(require, "lib.nvim.map")
local has_lib = ok_lib_map and type(lib_map) == "function"

---Set a keymap with buffer-ctx defaults (noremap + silent).
---@param modes string|string[]
---@param lhs string
---@param rhs string|function
---@param desc string  shown in which-key / :map listings
---@param opts? table  extra vim.keymap.set options, merged over the defaults
---@return nil
function M.set(modes, lhs, rhs, desc, opts)
  if type(lhs) ~= "string" or lhs == "" then return end
  if type(rhs) ~= "function" and type(rhs) ~= "string" then return end

  local merged = vim.tbl_extend("force", { noremap = true, silent = true }, opts or {})
  if has_lib then
    lib_map(modes, lhs, rhs, merged, desc)
    return
  end
  merged.desc = desc
  vim.keymap.set(modes, lhs, rhs, merged)
end

---Whether lib.nvim's map helper is in use (for :checkhealth reporting)
---@return boolean
function M.using_lib()
  return has_lib
end

return M
