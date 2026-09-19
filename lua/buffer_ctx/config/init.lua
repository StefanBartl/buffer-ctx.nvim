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
---
---A leaf's value is `true` when any value is accepted opaquely (validated
---downstream, e.g. by lib.nvim's keymap registry, or -- for `mark.keymaps` /
---`mark.sign` / `mark.categories` -- by `buffer_ctx.mark` itself), or a Lua
---`type()` name (`"boolean"`, `"string"`) when the field has exactly one
---valid type (ERR-22): a value of any other type is dropped here rather than
---merged in, so `vim.tbl_deep_extend` falls through to the default instead of
---using the bad value as-is or letting it reach code that assumes the right
---type (e.g. a non-string `format.command` reaching `composer.verb`).
---@type table<string, true|string|table<string, true|string>>
local KNOWN = {
  keymaps = { location_copy = true, module_copy = true, filepath_copy = true },
  commands = "boolean",
  timestamp = { utc = "boolean" },
  snippets = { paths = true },
  format = { enable = "boolean", command = "string" },
  mark = { enable = "boolean", command = "string", keymaps = true, sign = true, categories = true },
  which_key = "boolean",
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
---Whether `value` satisfies leaf spec `spec` (`true` = any value accepted
---opaquely, a `type()` name = exactly that type).
---@param spec true|string
---@param value any
---@return boolean
local function leaf_ok(spec, value)
  return spec == true or type(value) == spec
end

---@internal
---`option '<path>' must be <expected>, got <actual> -- using the default`
---@param path string
---@param expected string
---@param value any
---@return string
local function describe_invalid(path, expected, value)
  return string.format(
    "option '%s' must be %s, got %s -- using the default",
    path,
    expected,
    type(value)
  )
end

---@internal
---Drop what cannot be merged, and say so. A misspelled key, or a known key
---holding a value of the wrong type (ERR-22), would otherwise land in the
---active config as a dead or dangerous field with the default silently
---overridden by something callers never validated.
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
          local sub_known = known[sub_key]
          if sub_known == nil then
            issues[#issues + 1] = describe_unknown(sub_key, known, key .. ".")
          elseif leaf_ok(sub_known, sub_value) then
            nested[sub_key] = sub_value
          else
            -- Left out of `nested`, so the deep-merge below falls through to
            -- DEFAULTS[key][sub_key] instead of using the bad value as-is.
            issues[#issues + 1] = describe_invalid(key .. "." .. sub_key, sub_known, sub_value)
          end
        end
        clean[key] = nested
      end
    elseif leaf_ok(known, value) then
      clean[key] = value
    else
      -- Left out of `clean`, so the deep-merge below falls through to
      -- DEFAULTS[key] instead of using the bad value as-is.
      issues[#issues + 1] = describe_invalid(key, known, value)
    end
  end
  table.sort(issues)
  return clean, issues
end

--- Merge user options over the defaults and store the result.
---
--- Unknown keys and mistyped values -- whole option tables (ERR-50) or a
--- single leaf value of the wrong type (ERR-22) -- are reported once here and
--- again by `:checkhealth buffer_ctx` (see `issues()`); they never reach the
--- merge, so the default stays in force for whatever was dropped.
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

---What the last `setup()` ignored: unknown keys and values of the wrong
---type (a whole option table or a single leaf), one human-readable line
---each. Empty when everything was accepted.
---@return string[]
function M.issues()
  return vim.list_extend({}, _issues)
end

return M
