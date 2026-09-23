---@module 'buffer_ctx.ops.markdown_link'
--- Wraps a path string in a Markdown link ("[title](path)").
---
--- Delegates to markdown.nvim's own link builder when installed --
--- `markdown.commands.markdown_links.for_paths()`, the exact function behind
--- `:Markdown links <path>` -- so a single file's link is built by the same
--- code markdown.nvim itself uses, rather than a second, potentially
--- drifting copy of "[title](path)" here. Soft dependency, matching
--- commands.lua's `resolve_kit()` convention: `pcall(require, ...)`,
--- re-checked on every call (not cached at module load) so tests can swap
--- `package.loaded["markdown.commands.markdown_links"]` in and out.
---
--- Falls back to the same literal format inline when markdown.nvim is
--- absent -- unlike `buffer_ctx.ops.imagepaste`'s clipboard-read pipeline,
--- "[title](path)" is a one-line, config-independent format (markdown.nvim's
--- own `for_paths` hardcodes it too, see that module's `make_link`), so a
--- local fallback carries none of the platform-dispatch duplication risk
--- `buffer_ctx.ops.reveal` deliberately avoids for `reveal_in_fm`.
---@see buffer_ctx.ops.filepath for the path string this wraps (mode/format
---already cover absolute/cwd-relative/nvim-relative/$REPOS_DIR-relative)

local M = {}

---@internal
---@return boolean ok, table|nil markdown_links
local function resolve_markdown_links()
  return pcall(require, "markdown.commands.markdown_links")
end

---Wrap `path` in a Markdown link.
---@param path string
---@return string result
function M.build(path)
  local ok_md, markdown_links = resolve_markdown_links()
  if ok_md and type(markdown_links.for_paths) == "function" then
    return markdown_links.for_paths({ path })
  end
  return string.format("[%s](%s)", vim.fn.fnamemodify(path, ":t"), path)
end

return M
