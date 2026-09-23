---@module 'buffer_ctx.ops.imagepaste'
--- Delegates to images.nvim's clipboard-paste feature (`require("images").paste`,
--- `:Image paste` under the hood) -- soft dependency, matching commands.lua's
--- `resolve_kit()` convention: `pcall(require, ...)`, re-checked on every
--- call (not cached at module load) so tests can swap
--- `package.loaded["images"]` in and out.
---
--- Unlike every other `ops/*` module behind `:Insert`/`:Copy`, this is not a
--- text producer bound to the cursor/clipboard sink: images.nvim's own
--- `paste.run` reads the OS clipboard *asynchronously* and inserts the
--- resulting Markdown link directly into the current buffer at the cursor
--- itself (see `images/paste.lua`'s `insert_link`) -- the same "side effect
--- on an external resource, not a value returned to a sink" shape as
--- `buffer_ctx.ops.reveal`. There is therefore no `:Copy imagepaste`
--- (clipboard-sink) counterpart wired in commands.lua -- images.nvim's public
--- API has no "give me the link text instead of inserting it" mode, and
--- reimplementing its clipboard-read pipeline here just to intercept that one
--- step would duplicate platform-specific logic (`paste.lua`'s
--- Windows/macOS/Linux clipboard-to-file dispatch) that already exists once,
--- there, on purpose -- exactly the duplication `buffer_ctx.ops.reveal`
--- itself already declines for `reveal_in_fm`.
---@see buffer_ctx.ops.reveal for the same "side effect, no sink" shape
---@see images.paste for the delegated clipboard-to-file-to-link pipeline

local M = {}

---@internal
---@return boolean ok, table|nil images
local function resolve_images()
  return pcall(require, "images")
end

---Paste the clipboard image via images.nvim, inserting the resulting
---Markdown link at the cursor of the current buffer. Fire-and-forget:
---images.nvim's own `paste.run` is asynchronous (the clipboard read is a
---background process call) and reports its own success/failure through its
---own notifier, not back through this return value -- `ok = true` here means
---only "images.nvim accepted the call", not "the paste finished".
---@param name string|nil an explicit file name (`:Insert imagepaste {name}`); nil = images.nvim's own name prompt/template
---@param path_mode string|nil see `images.paste.resolve_link_path`; nil = images.nvim's own configured default
---@return boolean ok
---@return string|nil err
function M.paste(name, path_mode)
  local ok_images, images = resolve_images()
  if not ok_images or type(images.paste) ~= "function" then
    return false, "images.nvim not found (required for imagepaste)"
  end
  images.paste(name, nil, path_mode)
  return true, nil
end

return M
