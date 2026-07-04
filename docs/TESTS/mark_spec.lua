-- docs/TESTS/mark_spec.lua — buffer_ctx.mark: toggle/yank, invalid-buffer
-- guards, and the BufDelete/BufWipeout cleanup autocmd.

return function(H)
  require("buffer_ctx").setup()
  local mark = require("buffer_ctx.mark")

  -- basic toggle + yank flow
  local buf = H.scratch(vim.fn.getcwd() .. "/mark_test.lua")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three" })
  mark.toggle(1, buf)
  mark.toggle(3, buf)
  mark.yank(buf)
  H.eq(vim.fn.getreg("+"), "one\nthree", "mark.yank collects marked lines in buffer order")

  -- toggling the same line again removes the mark
  mark.toggle(1, buf)
  vim.fn.setreg("+", "") -- clear before re-yanking
  mark.yank(buf)
  H.eq(vim.fn.getreg("+"), "three", "re-toggling a marked line un-marks it")

  -- invalid buffer guards do not crash
  local toggle_ok = pcall(mark.toggle, 1, 999999)
  H.ok(toggle_ok, "mark.toggle on an invalid buffer does not error")

  local yank_ok = pcall(mark.yank, 999999)
  H.ok(yank_ok, "mark.yank on an invalid buffer does not error")

  -- BufDelete/BufWipeout cleanup autocmd is registered
  local autocmds = vim.api.nvim_get_autocmds({ group = "BufferCtxMarkCleanup" })
  local events = {}
  for _, ac in ipairs(autocmds) do events[ac.event] = true end
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
