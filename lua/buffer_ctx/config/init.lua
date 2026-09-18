---@module 'buffer_ctx.config'
--- Runtime configuration store for buffer-ctx.nvim.
--- Deep-merges user options over `buffer_ctx.config.DEFAULTS` and exposes a
--- single `get()` accessor so other modules never read a raw options table
--- directly.
---@see buffer_ctx.config.DEFAULTS
---@see buffer_ctx.@types

local M = {}

---@type BufferCtx.Config
local DEFAULTS = require("buffer_ctx.config.DEFAULTS")

local _active = nil

---What the last `setup()` had to ignore, for `:checkhealth`.
---@type string[]
local _issues = {}

---Keys `setup()` accepts and, for the option tables among them, their keys.
---A nested table's keys are validated one level deep; deeper structures
---(`mark.keymaps`, `mark.sign`, `mark.categories`) are accepted opaquely --
---their own shapes are documented in @types.lua and validated by the
---consumers that read them.
---@type table<string, true|table<string, true>>
local KNOWN = {
  keymaps = { location_copy = true, module_copy = true, filepath_copy = true },
  commands = true,
  timestamp = { utc = true },
  snippets = { paths = true },
  format = { enable = true, command = true },
  mark = { enable = true, command = true, keymaps = true, sign = true, categories = true },
  which_key = true,
}

-- Keys DEFAULTS holds as a table but whose user-facing type also allows a
-- plain boolean override (`keymaps = false`, `format = false`, `mark =
-- false` -- see @types.lua's `| boolean` unions). Without this, sanitize()
-- would misreport a deliberate `false` as "must be a table".
local BOOL_OVERRIDABLE = { keymaps = true, format = true, mark = true }

---@internal
---`key` with the nearest known one as a hint when there is a plausible one.
---@param key any
---@param known table<string, any>
---@param prefix string
---@return string
local function describe_unknown(key, known, prefix)
  local levenshtein = require("lib.lua.strings.distance").levenshtein
  local name = tostring(key)
  local best, best_distance = nil, nil
  for candidate in pairs(known) do
    local d = levenshtein(name, candidate)
    if d <= 3 and (best_distance == nil or d < best_distance) then
      best, best_distance = candidate, d
    end
  end
  if best then
    return string.format("unknown option '%s%s' (did you mean '%s%s'?)", prefix, name, prefix, best)
  end
  return string.format("unknown option '%s%s'", prefix, name)
end

---@internal
---Drop what cannot be merged, and say so. A misspelled key would otherwise
---land in the active config as a dead field with the default still in force.
---@param user_opts table
---@return table clean  the accepted subset, nested option tables copied
---@return string[] issues
local function sanitize(user_opts)
  local clean, issues = {}, {}
  for key, value in pairs(user_opts) do
    local known = KNOWN[key]
    if known == nil then
      issues[#issues + 1] = describe_unknown(key, KNOWN, "")
    elseif type(known) == "table" then
      if type(value) ~= "table" then
        if BOOL_OVERRIDABLE[key] then
          clean[key] = value
        else
          issues[#issues + 1] = string.format(
            "option '%s' must be a table, got %s -- using the default",
            key,
            type(value)
          )
        end
      else
        local nested = {}
        for sub_key, sub_value in pairs(value) do
          if known[sub_key] then
            nested[sub_key] = sub_value
          else
            issues[#issues + 1] = describe_unknown(sub_key, known, key .. ".")
          end
        end
        clean[key] = nested
      end
    else
      clean[key] = value
    end
  end
  table.sort(issues)
  return clean, issues
end

--- Merge user options over the defaults and store the result.
---
--- Unknown keys and mistyped option tables are reported once here and again
--- by `:checkhealth buffer_ctx` (see `issues()`); they never reach the merge.
---@param user_opts? BufferCtx.Config
function M.setup(user_opts)
  if user_opts ~= nil and type(user_opts) ~= "table" then
    error("buffer_ctx.setup: expected table or nil, got " .. type(user_opts), 2)
  end
  local clean, issues = sanitize(user_opts or {})
  _issues = issues
  if #issues > 0 then
    require("buffer_ctx.util.notify").warn("ignored config: " .. table.concat(issues, "; "))
  end
  _active = vim.tbl_deep_extend("force", DEFAULTS, clean)
end

---@return BufferCtx.Config
function M.get()
  return _active or DEFAULTS
end

---What the last `setup()` ignored: unknown keys and option tables of the
---wrong type, one human-readable line each. Empty when everything was
---accepted.
---@return string[]
function M.issues()
  return vim.list_extend({}, _issues)
end

return M
