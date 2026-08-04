---@module 'buffer_ctx.util.notify'
--- "[buffer-ctx] " prefixed vim.notify wrapper; upgrades to lib.nvim's
--- notifier when lib.nvim is installed. Soft dependency only: falls back to
--- plain vim.notify when lib.nvim is absent.

local PREFIX = "[buffer-ctx]"
local M = {}

---@internal
---@return table|nil
local function resolve()
  local ok, lib_notify = pcall(require, "lib.nvim.notify")
  if ok and type(lib_notify) == "table" and type(lib_notify.create) == "function" then
    local create_ok, notifier = pcall(lib_notify.create, PREFIX)
    if create_ok and type(notifier) == "table" then
      return notifier
    end
  end
  return nil
end

local lib = resolve()

---@param msg string
function M.info(msg)
  if lib then
    lib.info(msg)
  else
    vim.notify(PREFIX .. " " .. msg, vim.log.levels.INFO)
  end
end

---@param msg string
function M.warn(msg)
  if lib then
    lib.warn(msg)
  else
    vim.notify(PREFIX .. " " .. msg, vim.log.levels.WARN)
  end
end

---@param msg string
function M.error(msg)
  if lib then
    lib.error(msg)
  else
    vim.notify(PREFIX .. " " .. msg, vim.log.levels.ERROR)
  end
end

---@param msg string
function M.debug(msg)
  if lib then
    lib.debug(msg)
  else
    vim.notify(PREFIX .. " " .. msg, vim.log.levels.DEBUG)
  end
end

---Whether lib.nvim's notifier is in use (for :checkhealth reporting)
---@return boolean
function M.using_lib()
  return lib ~= nil
end

return M
