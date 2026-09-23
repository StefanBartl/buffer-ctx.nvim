---@module 'buffer_ctx.reveal'
--- :RevealInFm / :OpenInBrowser -- reveal the current buffer in the system
--- file manager, or hand it to the OS-registered application for it.
---
--- Two independent, argument-less actions -- unlike `:Mark`/`:Format` there
--- is no shared subcommand tree to route through here, so each gets its own
--- plain user command (via `lib.nvim.bindings.usercmd`, the same non-composer
--- helper the compat commands in `buffer_ctx.commands`/`buffer_ctx.mark` use)
--- rather than a `lib.nvim.bindings.usercmd.composer` verb.
---@see buffer_ctx.ops.reveal for the actual reveal_in_fm / open.nvim / vim.ui.open dispatch

local usercmd = require("lib.nvim.bindings.usercmd")
local notify = require("buffer_ctx.util.notify")
local map = require("buffer_ctx.util.map")
local reveal_op = require("buffer_ctx.ops.reveal")

local M = {}

---Reveal the current buffer in the system file manager.
function M.fm()
  local ok, err = reveal_op.fm()
  if not ok then
    notify.warn(err or "failed to open file manager")
  end
end

---Open the current buffer with the OS-registered application for it
---(a browser for a URL/`.html` file, whatever else the OS associates
---otherwise).
function M.browser()
  local ok, err = reveal_op.browser()
  if not ok then
    notify.warn(err or "failed to open browser")
  end
end

---@param opts BufferCtx.RevealConfig
function M.setup(opts)
  opts = opts or {}
  if opts.enable == false then
    return
  end

  usercmd.create(
    "RevealInFm",
    M.fm,
    { desc = "[buffer-ctx] Reveal current buffer in the system file manager" }
  )
  usercmd.create(
    "OpenInBrowser",
    M.browser,
    { desc = "[buffer-ctx] Open current buffer with the OS-registered application (browser)" }
  )

  local km = opts.keymaps
  if km and km ~= false then
    if type(km.fm) == "string" then
      map.set("n", km.fm, M.fm, "[buffer-ctx] Reveal current buffer in the file manager")
    end
    if type(km.browser) == "string" then
      map.set("n", km.browser, M.browser, "[buffer-ctx] Open current buffer in the browser")
    end
  end
end

return M
