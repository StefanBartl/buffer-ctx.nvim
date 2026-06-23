---@module 'buffer_ctx.ops.timestamp'
local M = {}

local FORMATS = {
  iso      = "%Y-%m-%dT%H:%M:%S",
  ["iso-date"] = "%Y-%m-%d",
  ["iso-time"] = "%H:%M:%S",
  human    = "%B %d, %Y %H:%M",
  short    = "%d.%m.%Y",
  log      = "%Y-%m-%d %H:%M:%S",
  filename = "%Y%m%d_%H%M%S",
}

---Format a timestamp
---@param fmt BufferCtx.TimestampFormat
---@param utc? boolean
---@return string
function M.format_timestamp(fmt, utc)
  local ts = os.time()
  fmt = (fmt or "iso"):lower()

  if fmt == "unix" then return tostring(ts) end

  local pattern = FORMATS[fmt] or FORMATS.iso
  if utc then
    return os.date("!" .. pattern, ts) --[[@as string]]
  end
  return os.date(pattern, ts) --[[@as string]]
end

---Parse fargs for timestamp subcommand
---@param args string[]
---@return BufferCtx.TimestampFormat, boolean
function M.parse_args(args)
  local fmt = "iso"
  local utc = false
  for _, a in ipairs(args or {}) do
    if a == "--utc" then
      utc = true
    else
      fmt = a:lower()
    end
  end
  return fmt, utc
end

return M
