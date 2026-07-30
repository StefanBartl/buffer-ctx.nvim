-- docs/TESTS/mark_spec.lua — buffer_ctx.mark: toggle/yank, invalid-buffer
-- guards, and the BufDelete/BufWipeout cleanup autocmd.

return function(H)
  require("buffer_ctx").setup()
  local mark = require("buffer_ctx.mark")

  -- The unnamed register is asserted instead of "+": util/clip.lua writes it
  -- unconditionally, whereas a write to "+" is silently dropped on machines
  -- without a clipboard provider (headless CI runners, minimal containers).
  -- Both carry the same text, so this tests the same behaviour portably.
  local function yanked()
    return vim.fn.getreg('"')
  end

  -- basic toggle + yank flow
  local buf = H.scratch(vim.fn.getcwd() .. "/mark_test.lua")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three" })
  mark.toggle(1, buf)
  mark.toggle(3, buf)
  mark.yank(buf)
  H.eq(yanked(), "one\nthree", "mark.yank collects marked lines in buffer order")

  -- toggling the same line again removes the mark
  mark.toggle(1, buf)
  vim.fn.setreg('"', "") -- clear before re-yanking
  mark.yank(buf)
  H.eq(yanked(), "three", "re-toggling a marked line un-marks it")

  -- Regression: marks must follow their line across edits above them.
  --
  -- Marks used to be keyed by raw line number, so inserting above a mark
  -- moved the visual indicator (Neovim tracks extmarks/signs) but not the
  -- stored key — and yank then copied whatever text had slid into the old
  -- line slot. See docs/ROADMAP/anchor-stable-marks.md.
  do
    local b = H.scratch(vim.fn.getcwd() .. "/mark_drift.lua")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "alpha", "beta", "gamma", "delta" })

    mark.toggle(3, b) -- "gamma"

    -- Two new lines above the mark: "gamma" is now line 5.
    vim.api.nvim_buf_set_lines(b, 0, 0, false, { "new1", "new2" })

    vim.fn.setreg('"', "")
    mark.yank(b)
    H.eq(yanked(), "gamma", "a mark follows its line when text is inserted above it")

    -- Toggling by the mark's *current* line must find and clear it.
    mark.toggle(5, b)
    vim.fn.setreg('"', "")
    mark.yank(b)
    H.eq(yanked(), "", "toggling the drifted line un-marks it")
  end

  -- Deleting a marked line drops the mark instead of yanking a stale line.
  do
    local b = H.scratch(vim.fn.getcwd() .. "/mark_deleted.lua")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "keep", "doomed", "tail" })

    mark.toggle(1, b)
    mark.toggle(2, b)
    vim.api.nvim_buf_set_lines(b, 1, 2, false, {}) -- delete "doomed"

    vim.fn.setreg('"', "")
    mark.yank(b)
    H.eq(yanked(), "keep", "a mark on a deleted line is dropped, not resolved to a neighbour")
  end

  -- Yank order follows buffer order, not the order marks were created in.
  do
    local b = H.scratch(vim.fn.getcwd() .. "/mark_order.lua")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "first", "second", "third" })

    mark.toggle(3, b) -- marked first, but lives last
    mark.toggle(1, b)

    vim.fn.setreg('"', "")
    mark.yank(b)
    H.eq(yanked(), "first\nthird", "yank sorts by resolved line, not by mark creation order")
  end

  -- invalid buffer guards do not crash
  local toggle_ok = pcall(mark.toggle, 1, 999999)
  H.ok(toggle_ok, "mark.toggle on an invalid buffer does not error")

  local yank_ok = pcall(mark.yank, 999999)
  H.ok(yank_ok, "mark.yank on an invalid buffer does not error")

  -- BufDelete/BufWipeout cleanup autocmd is registered
  local autocmds = vim.api.nvim_get_autocmds({ group = "BufferCtxMarkCleanup" })
  local events = {}
  for _, ac in ipairs(autocmds) do
    events[ac.event] = true
  end
  H.ok(events["BufDelete"], "BufferCtxMarkCleanup handles BufDelete")
  H.ok(events["BufWipeout"], "BufferCtxMarkCleanup handles BufWipeout")

  -- after wipeout, the buffer is invalid and yank must not crash
  local buf2 = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { "line one" })
  mark.toggle(1, buf2)
  vim.cmd("bwipeout! " .. buf2)
  local yank_after_wipe_ok = pcall(mark.yank, buf2)
  H.ok(yank_after_wipe_ok, "mark.yank after bwipeout does not error")
end
