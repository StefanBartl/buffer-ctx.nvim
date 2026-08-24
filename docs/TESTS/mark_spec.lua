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

  -- ─────────────────────────────────── range toggling, categories, clear

  ---A scratch buffer with `n` lines, marks cleared.
  ---@param n integer
  ---@return integer bufnr
  local function fresh(n)
    local b = vim.api.nvim_create_buf(false, true)
    local lines = {}
    for i = 1, n do
      lines[i] = "line " .. i
    end
    vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
    return b
  end

  do
    local b = fresh(5)

    -- toggle_range is deliberately NOT a per-line toggle: over a partially
    -- marked range, toggling each line leaves a checkerboard, which looks
    -- broken rather than useful.
    H.eq(mark.toggle_range(1, 3, b), 3, "toggle_range marks an unmarked range")
    H.eq(mark.toggle_range(1, 3, b), 3, "...and unmarks it when every line is marked")

    mark.toggle(4, b)
    H.eq(mark.toggle_range(1, 5, b), 4, "a partially marked range marks the remaining lines")
    H.eq(mark.toggle_range(1, 5, b), 5, "...and only then does the whole range unmark")

    -- Reversed bounds are the same range: a Visual selection made upwards
    -- hands them over in that order.
    H.eq(mark.toggle_range(3, 1, b), 3, "reversed bounds are normalized")
    mark.clear(b)

    H.eq(mark.clear(b), 0, "clear on a buffer with no marks removes nothing")
    mark.toggle_range(1, 4, b)
    H.eq(mark.clear(b), 4, "clear removes every mark")
    H.eq(mark.clear(b), 0, "...and is idempotent")
  end

  do
    -- Categories. `default` always exists; these two come from the spec
    -- harness's setup() call, so if that changes this is the check that says so.
    local b = fresh(4)

    mark.toggle(1, b, "default")
    mark.toggle(2, b, "default")
    H.eq(mark.clear(b, "nonexistent-category"), 0, "clearing an unused category removes nothing")
    H.eq(mark.clear(b, "default"), 2, "clearing a category removes only its marks")

    -- Re-marking a line in a different category must replace, not unmark:
    -- asking for one appearance on a line that has another means you want
    -- the new one, not nothing.
    mark.toggle(1, b, "default")
    mark.toggle(1, b, "default")
    H.eq(mark.clear(b), 0, "toggling the same category twice unmarks the line")

    mark.toggle(1, b)
    mark.toggle(1, b, "default")
    H.eq(mark.clear(b), 0, "an omitted category is the default one")
  end

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
