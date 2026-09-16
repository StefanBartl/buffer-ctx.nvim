-- TESTS/bindings_spec.lua — buffer_ctx.bindings: the keymap actions
-- (attach/copy_action), the usrcmds/autocmds sub-registrars, and the
-- top-level setup() that gates them on cfg.commands.

return function(H)
  local keymaps = require("buffer_ctx.bindings.keymaps")

  ---Find a registered entry by action name.
  ---@param bound table[]
  ---@param name string
  local function find(bound, name)
    for _, entry in ipairs(bound) do
      if entry.name == name then
        return entry
      end
    end
    return nil
  end

  -- ── attach: defaults ───────────────────────────────────────────────────────
  local bound_default = keymaps.attach(nil, nil)
  local module_entry = find(bound_default, "module_copy")
  H.ok(module_entry ~= nil, "attach(nil): module_copy action is declared")
  H.eq(module_entry.lhs, "<leader>cnm", "attach(nil): module_copy keeps its default lhs")
  H.ok(module_entry.bound, "attach(nil): module_copy is actually bound")

  -- Drive the bound action end-to-end: it should fetch, copy, and leave the
  -- result on the unnamed register (same convention as mark_spec.lua).
  H.scratch(vim.fn.getcwd() .. "/lua/bindtest/mod.lua")
  vim.fn.setreg('"', "")
  module_entry.rhs()
  -- module_copy copies the bare dotted module path (get_module_path()), not
  -- a require(...) statement — that's module.get_statement(), a separate op.
  H.eq(vim.fn.getreg('"'), "bindtest.mod", "module_copy action copies the module path")

  local location_entry = find(bound_default, "location_copy")
  vim.fn.setreg('"', "")
  location_entry.rhs()
  H.match(
    vim.fn.getreg('"'),
    "^lua/bindtest/mod%.lua:%d+$",
    "location_copy action copies path:line"
  )

  -- copy_action's error branch: an unnamed buffer makes filepath.get_path
  -- fail, which must be reported rather than raised.
  H.scratch(nil)
  local filepath_entry = find(bound_default, "filepath_copy")
  local action_ok = pcall(filepath_entry.rhs)
  H.ok(action_ok, "copy_action does not raise when the getter fails (unnamed buffer)")

  -- ── attach: user override + which_key = false ─────────────────────────────
  local bound_override = keymaps.attach({ location_copy = "<leader>zzz" }, false)
  local overridden = find(bound_override, "location_copy")
  H.eq(overridden.lhs, "<leader>zzz", "attach(overrides): location_copy takes the overridden lhs")

  -- ── attach: keymaps = false binds nothing (actions still declared) ────────
  local bound_off = keymaps.attach(false, nil)
  for _, entry in ipairs(bound_off) do
    H.eq(entry.bound, false, "attach(false): " .. entry.name .. " is declared but not bound")
  end

  -- ── usrcmds.setup(): delegates to buffer_ctx.commands.register() ──────────
  do
    local original = package.loaded["buffer_ctx.commands"]
    local calls = 0
    package.loaded["buffer_ctx.commands"] = {
      register = function()
        calls = calls + 1
      end,
    }
    require("buffer_ctx.bindings.usrcmds").setup()
    H.eq(calls, 1, "bindings.usrcmds.setup() calls buffer_ctx.commands.register() once")
    package.loaded["buffer_ctx.commands"] = original
  end

  -- ── autocmds.setup(): documented no-op, must not error ─────────────────────
  local autocmds_ok = pcall(require("buffer_ctx.bindings.autocmds").setup, {})
  H.ok(autocmds_ok, "bindings.autocmds.setup() does not error (documented no-op)")

  -- ── bindings.setup(): wires the three sub-registrars, gated by cfg.commands
  do
    local orig_usrcmds = package.loaded["buffer_ctx.bindings.usrcmds"]
    local orig_keymaps = package.loaded["buffer_ctx.bindings.keymaps"]
    local orig_autocmds = package.loaded["buffer_ctx.bindings.autocmds"]

    local usrcmds_calls, keymaps_calls, autocmds_calls = 0, 0, nil
    package.loaded["buffer_ctx.bindings.usrcmds"] = {
      setup = function()
        usrcmds_calls = usrcmds_calls + 1
      end,
    }
    package.loaded["buffer_ctx.bindings.keymaps"] = {
      attach = function(cfg, wk)
        keymaps_calls = keymaps_calls + 1
        return { cfg = cfg, wk = wk }
      end,
    }
    package.loaded["buffer_ctx.bindings.autocmds"] = {
      setup = function(cfg)
        autocmds_calls = cfg
      end,
    }

    package.loaded["buffer_ctx.bindings"] = nil
    local bindings = require("buffer_ctx.bindings")

    bindings.setup({ commands = false, keymaps = false, which_key = false })
    H.eq(usrcmds_calls, 0, "bindings.setup: commands = false skips usrcmds.setup()")
    H.eq(keymaps_calls, 1, "bindings.setup: keymaps.attach() is always called")
    H.eq(autocmds_calls.commands, false, "bindings.setup: autocmds.setup() receives the full cfg")

    bindings.setup({ commands = true })
    H.eq(usrcmds_calls, 1, "bindings.setup: commands = true calls usrcmds.setup()")

    package.loaded["buffer_ctx.bindings.usrcmds"] = orig_usrcmds
    package.loaded["buffer_ctx.bindings.keymaps"] = orig_keymaps
    package.loaded["buffer_ctx.bindings.autocmds"] = orig_autocmds
    package.loaded["buffer_ctx.bindings"] = nil
    require("buffer_ctx.bindings") -- restore the real module for later specs
  end
end
