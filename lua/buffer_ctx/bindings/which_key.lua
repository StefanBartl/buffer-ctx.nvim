---@module 'buffer_ctx.bindings.which_key'
---@brief Optional, guarded which-key group label for the `<leader>cn` prefix.
---@description
--- which-key is a **soft** dependency: if it is not installed this is a
--- no-op. When present, registers a single group label so buffer-ctx's
--- `<leader>cn*` keymaps (copy location, copy module path, copy filepath)
--- show up under a named "buffer-ctx" group instead of a bare prefix.
--- Individual key descriptions already come from each mapping's `desc`, so
--- nothing else needs registering. Supports both the which-key v3 (`add`)
--- and v2 (`register`) APIs.

local M = {}

---Register the `<leader>cn` group with which-key, if available.
---@return boolean registered
function M.setup()
  local ok, wk = pcall(require, "which-key")
  if not ok or type(wk) ~= "table" then
    return false
  end
  if type(wk.add) == "function" then
    -- which-key v3
    wk.add({ { "<leader>cn", group = "buffer-ctx: copy context" } })
    return true
  elseif type(wk.register) == "function" then
    -- which-key v2
    wk.register({ ["<leader>cn"] = { name = "+buffer-ctx: copy context" } }, { mode = "n" })
    return true
  end
  return false
end

---Whether which-key is installed (for :checkhealth reporting).
---@return boolean
function M.available()
  local ok, wk = pcall(require, "which-key")
  return ok and type(wk) == "table"
end

return M
