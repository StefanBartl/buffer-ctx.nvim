-- TESTS/cross_plugin_spec.lua — the two cross-plugin shims from
-- buffer_ctx.commands: "mdlink" (a pure text producer wired under both
-- :Insert and :Copy, delegating to markdown.nvim) and "imagepaste" (a
-- side-effecting :Insert-only route, delegating to images.nvim). Neither
-- sister plugin is ever actually invoked for real: markdown.nvim and
-- images.nvim are stubbed via package.loaded/package.preload, matching
-- reveal_spec.lua's own technique for lib.nvim/open.nvim.

return function(H)
  local markdown_link_op = require("buffer_ctx.ops.markdown_link")
  local imagepaste_op = require("buffer_ctx.ops.imagepaste")
  local commands = require("buffer_ctx.commands")
  local cwd = vim.fn.getcwd()

  ---@internal
  ---Run `fn()` with `require(name)` intercepted, restoring the real module
  ---(and `package.preload`) afterwards either way. See reveal_spec.lua's
  ---own copy of this helper for why `stub == false` needs the
  ---`package.preload` trick rather than just `package.loaded[name] = false`.
  ---@param name string
  ---@param stub any
  ---@param fn fun()
  local function with_module(name, stub, fn)
    local had_loaded, had_loaded_set = package.loaded[name], package.loaded[name] ~= nil
    local had_preload, had_preload_set = package.preload[name], package.preload[name] ~= nil

    package.loaded[name] = nil
    if stub == false then
      package.preload[name] = function()
        error("module '" .. name .. "' not found (test stub)", 0)
      end
    else
      package.loaded[name] = stub
    end

    local ok, err = pcall(fn)

    package.loaded[name] = had_loaded_set and had_loaded or nil
    package.preload[name] = had_preload_set and had_preload or nil

    if not ok then
      error(err, 0)
    end
  end

  -- ── markdown_link.build(): markdown.nvim installed, delegates to it ─────
  do
    local seen_paths
    with_module("markdown.commands.markdown_links", {
      for_paths = function(paths)
        seen_paths = paths
        return "[stubbed](" .. paths[1] .. ")"
      end,
    }, function()
      local result = markdown_link_op.build("lua/thing.lua")
      H.eq(
        result,
        "[stubbed](lua/thing.lua)",
        "markdown_link.build returns markdown.nvim's own result"
      )
    end)
    H.eq(#seen_paths, 1, "markdown_link.build hands markdown.nvim exactly one path")
    H.eq(seen_paths[1], "lua/thing.lua", "markdown_link.build forwards the given path verbatim")
  end

  -- ── markdown_link.build(): markdown.nvim absent, falls back inline ──────
  with_module("markdown.commands.markdown_links", false, function()
    local result = markdown_link_op.build("lua/thing.lua")
    H.eq(result, "[thing.lua](lua/thing.lua)", "markdown_link.build falls back to [title](path)")
  end)

  -- ── mdlink DISPATCH: end-to-end via M._dispatch, both sinks ───────
  with_module("markdown.commands.markdown_links", false, function()
    H.scratch(cwd .. "/lua/mdlinktest/thing.lua")

    vim.fn.setreg('"', "")
    commands._dispatch("mdlink", { "abs" }, "clip")
    local abs_result = vim.fn.getreg('"')
    H.match(
      abs_result,
      "^%[thing%.lua%]%(.*mdlinktest[/\\]thing%.lua%)$",
      "mdlink mode=abs via :Copy"
    )

    vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
    commands._dispatch("mdlink", { "cwd" }, "cursor")
    local inserted = vim.api.nvim_buf_get_lines(0, 0, -1, false)[1]
    H.eq(
      inserted,
      "[thing.lua](lua/mdlinktest/thing.lua)",
      "mdlink mode=cwd via :Insert (default mode when no args given)"
    )
  end)

  -- ── mdlink DISPATCH: parse errors surface like "filepath"'s own ──
  do
    H.scratch(cwd .. "/lua/mdlinktest2/thing.lua")
    local original_notify_error = require("buffer_ctx.util.notify").error
    local last_err
    require("buffer_ctx.util.notify").error = function(msg)
      last_err = msg
    end
    commands._dispatch("mdlink", { "not-a-real-mode" }, "clip")
    require("buffer_ctx.util.notify").error = original_notify_error
    H.match(last_err or "", "^%[mdlink%] unknown argument", "mdlink reports unknown arguments")
  end

  -- ── imagepaste.paste(): images.nvim installed, delegates with the right
  --    args (force_ask is always nil -- the shim never asks for a name
  --    beyond what images.nvim's own paste prompt already covers) ────────
  do
    local seen
    with_module("images", {
      paste = function(name, force_ask, path_mode)
        seen = { name = name, force_ask = force_ask, path_mode = path_mode }
      end,
    }, function()
      local ok, err = imagepaste_op.paste("shot.png", "absolute")
      H.eq(ok, true, "imagepaste.paste returns true when images.nvim accepts the call")
      H.eq(err, nil, "imagepaste.paste: no error when images.nvim accepts the call")
    end)
    H.eq(seen.name, "shot.png", "imagepaste.paste forwards the given name")
    H.eq(seen.force_ask, nil, "imagepaste.paste never forces the name prompt")
    H.eq(seen.path_mode, "absolute", "imagepaste.paste forwards the given path mode")
  end

  -- ── imagepaste.paste(): images.nvim absent ──────────────────────────────
  with_module("images", false, function()
    local ok, err = imagepaste_op.paste(nil, nil)
    H.eq(ok, false, "imagepaste.paste returns false when images.nvim is unavailable")
    H.match(err, "images%.nvim not found", "imagepaste.paste names the missing dependency")
  end)

  -- ── commands.lua wiring: :Insert has both shims, :Copy only mdlink ─
  do
    local composer = require("lib.nvim.bindings.usercmd.composer")
    -- Idempotent (usercmd.create defaults to force = true, same as
    -- reveal_spec.lua relies on): re-registering here just re-asserts the
    -- routes this spec inspects, regardless of what earlier specs in the
    -- suite already triggered via buffer_ctx.setup().
    commands.register()

    ---@param handle table
    ---@param subcmd string
    ---@return boolean
    local function has_route(handle, subcmd)
      for _, route in ipairs(handle:spec().routes or {}) do
        if route.path[1] == subcmd then
          return true
        end
      end
      return false
    end

    local registry = composer.registry()
    H.ok(registry.Insert ~= nil, ":Insert is registered")
    H.ok(registry.Copy ~= nil, ":Copy is registered")

    H.ok(has_route(registry.Insert, "imagepaste"), ":Insert has an 'imagepaste' route")
    H.ok(
      not has_route(registry.Copy, "imagepaste"),
      ":Copy has no 'imagepaste' route (no clipboard sink for it)"
    )

    H.ok(has_route(registry.Insert, "mdlink"), ":Insert has a 'mdlink' route")
    H.ok(has_route(registry.Copy, "mdlink"), ":Copy has a 'mdlink' route")
  end

  -- ── :Insert imagepaste end-to-end through the composer (args + kv) ─────
  do
    local seen
    with_module("images", {
      paste = function(name, force_ask, path_mode)
        seen = { name = name, force_ask = force_ask, path_mode = path_mode }
      end,
    }, function()
      vim.cmd("Insert imagepaste myshot path=absolute")
    end)
    H.eq(seen.name, "myshot", ":Insert imagepaste binds the bare name argument")
    H.eq(seen.path_mode, "absolute", ":Insert imagepaste binds the path=... kv argument")
  end
end
