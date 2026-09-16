-- TESTS/util_spec.lua — buffer_ctx.util.{clip,cursor,notify,map}: clip's
-- pure sink contract, cursor's buffer-mutation guards, and the
-- lib.nvim-present/absent soft-dependency branches shared by notify and map
-- (the same pattern util/path.lua and ops/uuid.lua use, exercised here since
-- these two have an easily observable difference between the two branches).

return function(H)
  -- ── clip.copy: pure sink, no notification side effects ────────────────────
  local clip = require("buffer_ctx.util.clip")

  vim.fn.setreg('"', "")
  local ok1, err1, preview1 = clip.copy("hello world")
  H.ok(ok1, "clip.copy succeeds for a normal string")
  H.eq(err1, nil, "clip.copy has no error on success")
  H.eq(preview1, "hello world", "clip.copy preview is the text itself when short")
  H.eq(vim.fn.getreg('"'), "hello world", "clip.copy always sets the unnamed register")

  local ok2, err2, preview2 = clip.copy("")
  H.eq(ok2, false, "clip.copy rejects an empty string")
  H.eq(err2, "nothing to copy", "clip.copy empty-string error message")
  H.eq(preview2, "", "clip.copy empty-string preview")

  local long = string.rep("x", 80)
  local _, _, preview3 = clip.copy(long)
  H.eq(#preview3, 60, "clip.copy truncates a long preview to 60 chars")
  H.eq(preview3:sub(-3), "...", "clip.copy's truncated preview ends with an ellipsis")

  -- ── cursor.insert_text / insert_lines ──────────────────────────────────────
  local cursor = require("buffer_ctx.util.cursor")

  local buf = H.scratch(vim.fn.getcwd() .. "/cursor_test.lua")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab" })
  vim.api.nvim_win_set_cursor(0, { 1, 1 })
  cursor.insert_text("XY")
  H.eq(
    vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1],
    "aXYb",
    "cursor.insert_text splices text in at the cursor column"
  )

  -- Empty/invalid text is a no-op rather than an error.
  local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  cursor.insert_text("")
  cursor.insert_text(nil)
  H.eq(
    table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "|"),
    table.concat(before, "|"),
    "cursor.insert_text is a no-op for empty/nil text"
  )

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line1", "line2" })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  cursor.insert_lines({ "new1", "new2" })
  H.eq(
    table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "|"),
    "line1|new1|new2|line2",
    "cursor.insert_lines inserts before the current row"
  )

  local before_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  cursor.insert_lines({})
  cursor.insert_lines(nil)
  H.eq(
    table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "|"),
    table.concat(before_lines, "|"),
    "cursor.insert_lines is a no-op for an empty/nil list"
  )

  -- ── notify / map: baseline lib.nvim-present state ──────────────────────────
  local notify = require("buffer_ctx.util.notify")
  local map = require("buffer_ctx.util.map")
  H.eq(notify.using_lib(), true, "notify.using_lib() is true with lib.nvim on the runtimepath")

  -- BUG, pinned rather than silently worked around: util/map.lua detects
  -- lib.nvim with `type(lib_map) == "function"`, but
  -- require("lib.nvim.bindings.keymap") returns a *table* that is merely
  -- made callable via `__call` (documented in that module's own header) —
  -- `type()` reports "table" regardless of `__call`, so this check is always
  -- false and buffer_ctx.util.map never actually uses lib.nvim's keymap
  -- helper, even when it is installed. See the final test-coverage report.
  H.eq(map.using_lib(), false, "BUG: map.using_lib() is always false, even with lib.nvim present")

  -- ── notify: fallback path when lib.nvim.notify is unavailable ─────────────
  -- Module-level: `resolve()` runs once at require time, so the fallback is
  -- observed by shadowing the require *before* loading a fresh module copy,
  -- then restoring the real cached module afterwards.
  do
    local original_module = package.loaded["buffer_ctx.util.notify"]
    local original_preload = package.preload["lib.nvim.notify"]
    package.loaded["lib.nvim.notify"] = nil
    package.preload["lib.nvim.notify"] = function()
      error("simulated: lib.nvim.notify not installed")
    end
    package.loaded["buffer_ctx.util.notify"] = nil

    local fallback_notify = require("buffer_ctx.util.notify")
    H.eq(fallback_notify.using_lib(), false, "notify falls back when lib.nvim.notify is absent")

    local captured = {}
    local original_vim_notify = vim.notify
    vim.notify = function(msg, level)
      captured[#captured + 1] = { msg = msg, level = level }
    end
    fallback_notify.info("hi")
    fallback_notify.error("oops")
    vim.notify = original_vim_notify

    H.eq(captured[1].msg, "[buffer-ctx] hi", "notify fallback prefixes info messages")
    H.eq(captured[1].level, vim.log.levels.INFO, "notify fallback uses the INFO level")
    H.eq(captured[2].msg, "[buffer-ctx] oops", "notify fallback prefixes error messages")
    H.eq(captured[2].level, vim.log.levels.ERROR, "notify fallback uses the ERROR level")

    package.preload["lib.nvim.notify"] = original_preload
    package.loaded["lib.nvim.notify"] = nil -- force a clean re-resolve for anything requiring it later
    package.loaded["buffer_ctx.util.notify"] = original_module
  end

  -- ── map: fallback path when lib.nvim's keymap helper is unavailable ──────
  do
    local original_module = package.loaded["buffer_ctx.util.map"]
    local original_preload = package.preload["lib.nvim.bindings.keymap"]
    package.loaded["lib.nvim.bindings.keymap"] = nil
    package.preload["lib.nvim.bindings.keymap"] = function()
      error("simulated: lib.nvim.bindings.keymap not installed")
    end
    package.loaded["buffer_ctx.util.map"] = nil

    local fallback_map = require("buffer_ctx.util.map")
    H.eq(fallback_map.using_lib(), false, "map falls back when lib.nvim's keymap helper is absent")

    fallback_map.set("n", "<F13>", function() end, "spec-only test mapping")
    local mapping = vim.fn.maparg("<F13>", "n", false, true)
    H.ok(
      mapping and mapping.lhs ~= nil and mapping.lhs ~= "",
      "map fallback binds via vim.keymap.set"
    )
    pcall(vim.keymap.del, "n", "<F13>")

    -- Invalid lhs/rhs are guarded against rather than raised.
    local set_ok = pcall(fallback_map.set, "n", "", function() end, "no lhs")
    H.ok(set_ok, "map.set with an empty lhs does not error")
    local set_ok2 = pcall(fallback_map.set, "n", "<F14>", 123, "bad rhs")
    H.ok(set_ok2, "map.set with a non-function/string rhs does not error")

    package.preload["lib.nvim.bindings.keymap"] = original_preload
    package.loaded["lib.nvim.bindings.keymap"] = nil
    package.loaded["buffer_ctx.util.map"] = original_module
  end
end
