---@module 'buffer_ctx.bindings.keymaps'
--- The three base keymaps, declared as named actions.
---
--- All three do the same thing to different text: fetch it, put it on the
--- clipboard, say what was copied. That shape was written out three times
--- here, once per key; it is `copy_action` now, so a change to how copying
--- reports itself is one edit rather than three that can drift apart.
---
--- Declared through `lib.nvim.bindings.keymap`'s registry. The config shape is
--- unchanged -- `keymaps = false` binds nothing, `true` or `nil` takes the
--- defaults, and a table overrides individual keys -- and a wrong name is now
--- reported instead of silently binding nothing.
---@see buffer_ctx.util.map for the lib.nvim soft bridge the one-off maps use

local keymap = require("lib.nvim.bindings.keymap")

local M = {}

---@internal
--- Fetch a string, copy it, and report either way.
---
--- The `(value, err)` shape is what every `buffer_ctx.ops.*` getter returns,
--- so the error path is identical for all three and does not need repeating.
---@param get fun(): string|nil, string|nil
---@param what string  # Names the failure, e.g. "location"
---@return fun(): nil
local function copy_action(get, what)
  return function()
    local notify = require("buffer_ctx.util.notify")
    local result, err = get()
    if not result then
      notify.error(err or (what .. " failed"))
      return
    end
    local copy_ok, copy_err, preview = require("buffer_ctx.util.clip").copy(result)
    if copy_ok then
      notify.info("copied: " .. preview)
    else
      notify.warn(copy_err or "copy failed")
    end
  end
end

--- Declare and bind the base actions.
---@param cfg BufferCtx.KeymapConfig|boolean|nil
---@param which_key boolean|nil  # `false` skips the group label only.
---@return Lib.Keymap.Registered[]
function M.attach(cfg, which_key)
  ---@type Lib.Keymap.Spec
  local spec = {
    prefix = "<leader>cn",
    which_key = which_key ~= false and { group = "buffer-ctx: copy context" } or nil,
    order = { "location_copy", "module_copy", "filepath_copy" },
    actions = {
      location_copy = {
        default = "<leader>cnl",
        rhs = copy_action(function()
          return require("buffer_ctx.ops.location").get("cwd")
        end, "location"),
        desc = "copy location (path:line)",
      },

      module_copy = {
        default = "<leader>cnm",
        rhs = copy_action(function()
          return require("buffer_ctx.ops.module").get_module_path()
        end, "module"),
        desc = "copy module path",
      },

      filepath_copy = {
        default = "<leader>cnf",
        rhs = copy_action(function()
          return require("buffer_ctx.ops.filepath").get_path({
            mode = "cwd",
            format = "unix",
            depth = nil,
          })
        end, "filepath"),
        desc = "copy filepath (cwd-relative)",
      },
    },
  }

  -- `keymaps = true` means "take the defaults", which is what handing the
  -- registry no override table already says.
  --
  -- Spelled out rather than as `cond and cfg or nil`: that idiom cannot carry
  -- a `false` value -- `and` yields the false, `or` then replaces it -- so
  -- `keymaps = false` would silently arrive as nil and bind the defaults,
  -- which is the exact opposite of what it asks for.
  ---@type table|false|nil
  local user = nil
  if type(cfg) == "table" or cfg == false then
    user = cfg
  end

  return keymap.register("buffer-ctx", spec, user)
end

return M
