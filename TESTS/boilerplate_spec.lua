-- TESTS/boilerplate_spec.lua — buffer_ctx.ops.boilerplate: every registered
-- template renders, the has_id/no-id and default-fallback branches of each
-- template module (lua/html/nvim/markdown/utils), and the registry's
-- unknown-key error path.
--
-- guard-clause (interactive, via kit.form + kit.sync) is covered end-to-end
-- in features_spec.lua; this file only exercises its plain M.guard() helper.

return function(H)
  local boiler = require("buffer_ctx.ops.boilerplate")

  -- Every registered template renders non-empty lines without an id.
  for _, key in ipairs(boiler.list_keys()) do
    if key ~= "guard-clause" then
      local lines, err = boiler.get(key, nil)
      H.ok(lines and #lines > 0, "boilerplate " .. key .. " renders (" .. tostring(err) .. ")")
    end
  end

  -- has_id templates splice the id into the output.
  local WITH_ID = {
    "html-figure",
    "html-code",
    "html-quote",
    "html-formula-table",
    "html-aside",
    "html-pagination",
    "html-accordion",
    "html-table",
    "html-section",
    "lua-class",
    "lua-test",
    "lua-enum",
    "md-frontmatter",
  }
  for _, key in ipairs(WITH_ID) do
    local lines = boiler.get(key, "myid")
    local joined = table.concat(lines, "\n")
    H.ok(joined:find("myid", 1, true) ~= nil, "boilerplate " .. key .. " honours the id arg")
  end

  -- Unknown template key.
  local nolines, err = boiler.get("does-not-exist", nil)
  H.eq(nolines, nil, "boilerplate.get unknown key returns nil")
  H.match(err, "unknown template", "boilerplate.get unknown key error message")

  -- ── lua.lua: default-fallback branches ─────────────────────────────────────
  local lua_tmpl = require("buffer_ctx.ops.boilerplate.templates.lua")

  H.scratch(vim.fn.getcwd() .. "/lua/bp/thing.lua")
  local mod_lines = lua_tmpl.module(nil)
  H.eq(mod_lines[1], "---@module 'bp.thing'", "lua.module() defaults to the buffer's module path")
  local mod_named = lua_tmpl.module("explicit.name")
  H.eq(mod_named[1], "---@module 'explicit.name'", "lua.module(name) uses the given name")

  local class_default = lua_tmpl.class(nil)
  H.match(class_default[1], "^%-%-%-@class MyClass$", "lua.class() defaults to MyClass")
  local class_named = lua_tmpl.class("Widget")
  H.match(class_named[1], "^%-%-%-@class Widget$", "lua.class(name) uses the given name")

  local func_lines = lua_tmpl.func()
  H.ok(#func_lines > 0, "lua.func() renders")

  local test_default = lua_tmpl.test(nil)
  H.match(test_default[1], '^describe%("bp%.thing"', "lua.test() defaults to the module path")
  local test_named = lua_tmpl.test("some.subject")
  H.match(test_named[1], '^describe%("some%.subject"', "lua.test(subject) uses the given subject")

  local enum_default = lua_tmpl.enum(nil)
  H.match(enum_default[1], "^%-%-%-@alias MyEnum$", "lua.enum() defaults to MyEnum")
  local enum_named = lua_tmpl.enum("Color")
  H.match(enum_named[1], "^%-%-%-@alias Color$", "lua.enum(name) uses the given name")

  -- ── nvim.lua: default-fallback branches ────────────────────────────────────
  local nvim_tmpl = require("buffer_ctx.ops.boilerplate.templates.nvim")
  local autocmd_default = nvim_tmpl.autocmd(nil)
  H.match(autocmd_default[1], "MyGroup", "nvim.autocmd() defaults to MyGroup")
  local autocmd_named = nvim_tmpl.autocmd("MyAugroup")
  H.match(autocmd_named[1], "MyAugroup", "nvim.autocmd(name) uses the given name")
  H.ok(#nvim_tmpl.keymap() > 0, "nvim.keymap() renders")

  -- ── markdown.lua: title default falls back to buffer filename, then TODO ──
  local md_tmpl = require("buffer_ctx.ops.boilerplate.templates.markdown")
  H.scratch(vim.fn.getcwd() .. "/notes/My Post.md")
  local fm_from_name = md_tmpl.frontmatter(nil)
  H.match(fm_from_name[2], 'title: "My Post"', "markdown.frontmatter() defaults to the filename")
  local fm_explicit = md_tmpl.frontmatter("Explicit Title")
  H.match(
    fm_explicit[2],
    'title: "Explicit Title"',
    "markdown.frontmatter(title) uses the given title"
  )

  H.scratch(nil)
  local fm_unnamed = md_tmpl.frontmatter(nil)
  H.match(
    fm_unnamed[2],
    'title: "TODO"',
    "markdown.frontmatter() on an unnamed buffer falls back to TODO"
  )

  -- ── utils.lua: module path derivation used by lua.module/lua.test ─────────
  local utils = require("buffer_ctx.ops.boilerplate.templates.utils")
  H.scratch(vim.fn.getcwd() .. "/README-bp.md") -- outside any /lua/ directory
  H.eq(
    utils.get_module_path(),
    "module.name",
    "boilerplate utils.get_module_path() falls back outside a /lua/ directory"
  )

  -- ── guard.lua: the plain, non-interactive helper ───────────────────────────
  local guard = require("buffer_ctx.ops.boilerplate.templates.guard")
  local guard_default = guard.guard(nil, nil)
  H.eq(guard_default[1], "if condition then", "guard.guard() defaults condition to 'condition'")
  local guard_negated = guard.guard("ready", true)
  H.eq(guard_negated[1], "if not ready then", "guard.guard(condition, true) negates the check")
end
