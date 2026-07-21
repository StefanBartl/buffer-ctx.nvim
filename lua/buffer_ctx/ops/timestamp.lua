---@module 'buffer_ctx.ops.timestamp'
local M = {}

local FORMATS = {
  iso = "%Y-%m-%dT%H:%M:%S",
  ["iso-date"] = "%Y-%m-%d",
  ["iso-time"] = "%H:%M:%S",
  human = "%B %d, %Y %H:%M",
  short = "%d.%m.%Y",
  log = "%Y-%m-%d %H:%M:%S",
  filename = "%Y%m%d_%H%M%S",
  time = "%H:%M:%S",
}

-- %A/%a (weekday) and %B/%b (month) are locale-dependent in os.date (e.g. German
-- locale renders %a as "Di" instead of "Tue"), so "long"/"weekday"/"rfc2822" are
-- built from fixed English names instead, matching the plain-English "human" format.
local WEEKDAY_NAMES =
  { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
local MONTH_NAMES = {
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
}

---Format a timestamp
---@param fmt BufferCtx.TimestampFormat
---@param utc? boolean
---@return string
function M.format_timestamp(fmt, utc)
  local ts = os.time()
  fmt = (fmt or "iso"):lower()

  if fmt == "unix" then
    return tostring(ts)
  end

  if fmt == "12h" then
    -- os.date's %p (AM/PM) is unsupported by Windows' C runtime and silently
    -- vanishes from the output, so the 12-hour clock is built by hand instead
    -- of via a strftime pattern.
    local t = utc and os.date("!*t", ts) or os.date("*t", ts) --[[@as osdate]]
    local hour = t.hour % 12
    if hour == 0 then
      hour = 12
    end
    return string.format("%02d:%02d:%02d %s", hour, t.min, t.sec, t.hour < 12 and "AM" or "PM")
  end

  if fmt == "weekday" or fmt == "long" or fmt == "rfc2822" then
    local t = utc and os.date("!*t", ts) or os.date("*t", ts) --[[@as osdate]]
    local weekday = WEEKDAY_NAMES[t.wday]
    local month = MONTH_NAMES[t.month]
    if fmt == "weekday" then
      return weekday
    end
    if fmt == "long" then
      return string.format("%s, %s %d, %d", weekday, month, t.day, t.year)
    end
    return string.format(
      "%s, %02d %s %d %02d:%02d:%02d",
      weekday:sub(1, 3),
      t.day,
      month:sub(1, 3),
      t.year,
      t.hour,
      t.min,
      t.sec
    )
  end

  local pattern = FORMATS[fmt] or FORMATS.iso
  if utc then
    return os.date("!" .. pattern, ts) --[[@as string]]
  end
  return os.date(pattern, ts) --[[@as string]]
end

---@param args string[]
---@param default_fmt BufferCtx.TimestampFormat
---@return BufferCtx.TimestampFormat, boolean
local function parse_common(args, default_fmt)
  local fmt = default_fmt
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

---Parse fargs for timestamp subcommand
---@param args string[]
---@return BufferCtx.TimestampFormat, boolean
function M.parse_args(args)
  return parse_common(args, "iso")
end

---Parse fargs for the `date` subcommand (same grammar, defaults to iso-date)
---@param args string[]
---@return BufferCtx.TimestampFormat, boolean
function M.parse_date_args(args)
  return parse_common(args, "iso-date")
end

return M
