---@module 'buffer_ctx.bindings.keymaps'
---@see buffer_ctx.util.map for the lib.nvim soft bridge these go through

local M = {}

local map = require("buffer_ctx.util.map")

---@param cfg BufferCtx.KeymapConfig
function M.attach(cfg)
  if not cfg or type(cfg) ~= "table" then
    return
  end

  if cfg.location_copy then
    map.set("n", cfg.location_copy, function()
      local result, err = require("buffer_ctx.ops.location").get("cwd")
      if not result then
        require("buffer_ctx.util.notify").error(err or "location failed")
        return
      end
      require("buffer_ctx.util.clip").copy(result)
    end, "[buffer-ctx] copy location (path:line)")
  end

  if cfg.module_copy then
    map.set("n", cfg.module_copy, function()
      local mod, err = require("buffer_ctx.ops.module").get_module_path()
      if not mod then
        require("buffer_ctx.util.notify").error(err or "module failed")
        return
      end
      require("buffer_ctx.util.clip").copy(mod)
    end, "[buffer-ctx] copy module path")
  end

  if cfg.filepath_copy then
    map.set("n", cfg.filepath_copy, function()
      local opts = { mode = "cwd", format = "unix", depth = nil }
      local result, err = require("buffer_ctx.ops.filepath").get_path(opts)
      if not result then
        require("buffer_ctx.util.notify").error(err or "filepath failed")
        return
      end
      require("buffer_ctx.util.clip").copy(result)
    end, "[buffer-ctx] copy filepath (cwd-relative)")
  end
end

return M
