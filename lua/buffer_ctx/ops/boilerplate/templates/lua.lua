---@module 'buffer_ctx.ops.boilerplate.templates.lua'
local utils = require("buffer_ctx.ops.boilerplate.templates.utils")
local M = {}

function M.module(name)
  name = name or utils.get_module_path()
  return {
    string.format("---@module '%s'", name),
    "---@brief TODO: Add brief description",
    "",
    "local M = {}",
    "",
    "---TODO: Add function description",
    "---@return nil",
    "function M.setup()",
    "  -- TODO: Implementation",
    "end",
    "",
    "return M",
  }
end

function M.class(class_name)
  class_name = class_name or "MyClass"
  return {
    string.format("---@class %s", class_name),
    "---@field private _data table",
    string.format("local %s = {}", class_name),
    string.format("%s.__index = %s", class_name, class_name),
    "",
    "---@param opts? table",
    string.format("---@return %s", class_name),
    string.format("function %s.new(opts)", class_name),
    "  opts = opts or {}",
    string.format("  local self = setmetatable({}, %s)", class_name),
    "  self._data = opts",
    "  return self",
    "end",
    "",
    string.format("return %s", class_name),
  }
end

function M.func()
  return {
    "---TODO: Add description",
    "---@param arg1 any",
    "---@return any",
    "local function function_name(arg1)",
    "  -- TODO: Implementation",
    "end",
  }
end

return M
