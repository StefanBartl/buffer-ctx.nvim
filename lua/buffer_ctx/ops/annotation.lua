---@module 'buffer_ctx.ops.annotation'
local M = {}
local api    = vim.api
local fn     = vim.fn
local pu     = require("buffer_ctx.util.path")
local notify = require("buffer_ctx.util.notify")

---Get a single-line annotation string
---Returns nil for "function" (interactive, returns lines[])
---@param ann_type BufferCtx.AnnotationType
---@param args string[]  remaining args after annotation type
---@return string|string[]|nil result, string|nil err
function M.get(ann_type, args)
  local t = (ann_type or "module"):lower()

  if t == "module" then
    local name = api.nvim_buf_get_name(0)
    if not name or name == "" then return nil, "unnamed buffer" end
    local mod = pu.get_module_path(fn.fnamemodify(name, ":p"))
    if not mod then return nil, "not inside a /lua/ directory" end
    return string.format("---@module '%s'", mod)

  elseif t == "class" then
    local class_name = args[1] or fn.input("Class name: ")
    if not class_name or class_name == "" then return nil, "class name required" end
    return string.format("---@class %s", class_name)

  elseif t == "field" then
    local fname = args[1] or fn.input("Field name: ")
    local ftype = args[2] or fn.input("Field type: ")
    if not fname or fname == "" then return nil, "field name required" end
    ftype = (ftype ~= "") and ftype or "any"
    return string.format("---@field %s %s", fname, ftype)

  elseif t == "param" then
    local pname = args[1] or fn.input("Param name: ")
    local ptype = args[2] or fn.input("Param type: ")
    if not pname or pname == "" then return nil, "param name required" end
    ptype = (ptype ~= "") and ptype or "any"
    return string.format("---@param %s %s", pname, ptype)

  elseif t == "return" then
    local rtype = args[1] or fn.input("Return type: ")
    rtype = (rtype ~= "") and rtype or "any"
    return string.format("---@return %s", rtype)

  elseif t == "alias" then
    local aname = args[1] or fn.input("Alias name: ")
    local atype = args[2] or fn.input("Alias type: ")
    if not aname or aname == "" then return nil, "alias name required" end
    atype = (atype ~= "") and atype or "string"
    return string.format("---@alias %s %s", aname, atype)

  elseif t == "function" then
    return M._interactive_function()
  end

  return nil, "unknown annotation type: " .. t
end

---Interactive multi-line @param/@return dialog
---@return string[]|nil
function M._interactive_function()
  local desc = fn.input("Function description: ")

  local params = {}
  while true do
    local pname = fn.input("Param name (empty to stop): ")
    if pname == "" then break end
    local ptype = fn.input("  " .. pname .. " type: ")
    params[#params + 1] = { name = pname, type = ptype ~= "" and ptype or "any" }
  end

  local ret_type = fn.input("Return type (empty to skip): ")

  local lines = {}
  if desc ~= "" then
    lines[#lines + 1] = "---" .. desc
  end
  for _, p in ipairs(params) do
    lines[#lines + 1] = string.format("---@param %s %s", p.name, p.type)
  end
  if ret_type ~= "" then
    lines[#lines + 1] = "---@return " .. ret_type
  end

  if #lines == 0 then return nil, "no annotation generated" end
  return lines
end

return M
