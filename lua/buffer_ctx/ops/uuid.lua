---@module 'buffer_ctx.ops.uuid'
local M = {}

-- Seed once per session for better entropy
math.randomseed(vim.uv.hrtime())

local function rand_hex(n)
  local h = "0123456789abcdef"
  local s = {}
  for _ = 1, n do
    s[#s + 1] = h:sub(math.random(1, 16), math.random(1, 16))
  end
  return table.concat(s)
end

---Generate a UUID v4 string
---@return string  e.g. "550e8400-e29b-41d4-a716-446655440000"
function M.generate()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return template:gsub("[xy]", function(c)
    local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
    return string.format("%x", v)
  end)
end

---Format a UUID string
---@param uuid string
---@param fmt BufferCtx.UUIDFormat
---@return string
function M.format(uuid, fmt)
  fmt = (fmt or "standard"):lower()
  if fmt == "compact" then
    return uuid:gsub("-", "")
  elseif fmt == "upper" then
    return uuid:upper()
  elseif fmt == "braced" then
    return "{" .. uuid .. "}"
  end
  return uuid
end

---Get a formatted UUID
---@param fmt? BufferCtx.UUIDFormat
---@return string
function M.get(fmt)
  return M.format(M.generate(), fmt or "standard")
end

---Parse fargs for uuid subcommand
---@param args string[]
---@return BufferCtx.UUIDFormat
function M.parse_args(args)
  return (args and args[1]) and args[1]:lower() or "standard"
end

return M
