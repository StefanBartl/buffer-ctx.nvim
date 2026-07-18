-- docs/TESTS/features_spec.lua — the subcommands added on top of the original
-- catalog: git, bufinfo, snippet, location range, the new annotation types and
-- boilerplate templates, sticky-UTC config and env completion.

return function(H)
  local cwd = vim.fn.getcwd()

  -- ── annotation: overload / diagnostic / deprecated ───────────────────────
  local ann = require("buffer_ctx.ops.annotation")

  H.eq(
    ann.get("overload", { "fun(a:", "string):", "boolean" }),
    "---@overload fun(a: string): boolean",
    "annotation overload rejoins whitespace-split fargs"
  )
  H.eq(
    ann.get("overload", { "a:", "string" }),
    "---@overload fun(a: string)",
    "annotation overload wraps a bare signature in fun(...)"
  )
  H.eq(
    ann.get("diagnostic", { "undefined-field" }),
    "---@diagnostic disable-next-line: undefined-field",
    "annotation diagnostic"
  )
  H.eq(
    ann.get("deprecated", { "use", "M.new", "instead" }),
    "---@deprecated use M.new instead",
    "annotation deprecated keeps the full reason"
  )
  local _, ann_err = ann.get("nonsense", {})
  H.ok(ann_err ~= nil, "unknown annotation type returns an error")

  -- ── bufinfo ──────────────────────────────────────────────────────────────
  local bufinfo = require("buffer_ctx.ops.bufinfo")
  local buf = H.scratch(cwd .. "/features_test.lua")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c", "d" })
  H.eq(bufinfo.get_linecount(), "4", "bufinfo linecount")
  H.eq(bufinfo.get_bufnr(), tostring(buf), "bufinfo bufnr matches current buffer")

  -- ── git ──────────────────────────────────────────────────────────────────
  local git = require("buffer_ctx.ops.git")
  H.eq(git.parse_args({}), "short", "git parse_args default")
  H.eq(git.parse_args({ "BRANCH" }), "branch", "git parse_args lowercases")
  local _, git_err = git.get("bogus")
  H.ok(git_err ~= nil, "unknown git mode returns an error")
  -- The suite runs inside this repo, so a real query must succeed.
  if vim.fn.executable("git") == 1 then
    local sha = git.get("hash")
    H.match(sha or "", "^%x%x%x%x%x%x%x+$", "git hash is a hex sha")
    local short = git.get("short")
    H.ok(short and #short < #sha, "git short is shorter than the full hash")
  end

  -- ── location range ───────────────────────────────────────────────────────
  local location = require("buffer_ctx.ops.location")
  local mode, want_range = location.parse_args({ "abs", "range" })
  H.eq(mode, "abs", "location parse_args keeps the mode alongside range")
  H.eq(want_range, true, "location parse_args detects range")
  H.eq(select(2, location.parse_args({ "cwd" })), false, "location range defaults to false")

  H.scratch(cwd .. "/lua/rng/test.lua")
  H.eq(
    location.get_range("cwd", 10, 20),
    "lua/rng/test.lua:L10-L20",
    "location get_range formats an explicit range"
  )
  H.eq(
    location.get_range("cwd", 20, 10),
    "lua/rng/test.lua:L10-L20",
    "location get_range normalises a reversed range"
  )
  H.eq(
    location.get_range("cwd", 7, 7),
    "lua/rng/test.lua:7",
    "location get_range collapses a single-line range to path:line"
  )

  -- ── snippet ──────────────────────────────────────────────────────────────
  local snippet = require("buffer_ctx.ops.snippet")
  local snip_path = vim.fn.tempname() .. ".json"
  vim.fn.writefile({
    '{ "For Loop": { "prefix": "forl",',
    '    "body": ["for ${1:i} = 1, ${2:10} do", "  $0", "end"] },',
    '  "Choice": { "prefix": "ch", "body": "local ${1|alpha,beta|} = 1" },',
    '  "Plain":  { "prefix": "pl", "body": "just text" } }',
  }, snip_path)

  snippet.set_sources({ snip_path })
  H.eq(#snippet.get_sources(), 1, "snippet sources are configurable")

  local body = snippet.get("forl")
  H.eq(body and body[1], "for i = 1, 10 do", "snippet strips ${n:default} to the default")
  H.eq(body and body[2], "  ", "snippet drops bare $0 tabstops")
  H.ok(
    vim.deep_equal(snippet.get("For Loop"), body),
    "snippet resolves by name and by prefix alike"
  )
  H.eq(snippet.get("ch")[1], "local alpha = 1", "snippet takes the first choice of ${n|a,b|}")
  H.eq(snippet.get("pl")[1], "just text", "snippet accepts a string body")

  local _, snip_err = snippet.get("does-not-exist")
  H.ok(snip_err ~= nil, "unknown snippet returns an error")

  snippet.set_sources({})
  local _, no_src = snippet.get("forl")
  H.ok(no_src ~= nil, "snippet without sources returns an error instead of crashing")
  vim.fn.delete(snip_path)

  -- ── boilerplate: new templates + describe() ──────────────────────────────
  local boiler = require("buffer_ctx.ops.boilerplate")
  local descs = boiler.describe()
  for _, key in ipairs({ "lua-test", "lua-enum", "html-table", "html-section", "md-frontmatter" }) do
    local lines, err = boiler.get(key, nil)
    H.ok(lines and #lines > 0, "boilerplate " .. key .. " renders (" .. tostring(err) .. ")")
    H.ok(descs[key] ~= nil, "boilerplate " .. key .. " has a description")
  end
  H.eq(
    boiler.get("html-section", "intro")[1],
    '<section id="#sec-intro">',
    "boilerplate honours the id arg"
  )

  -- ── env completion ───────────────────────────────────────────────────────
  local env_op = require("buffer_ctx.ops.env")
  vim.fn.setenv("BUFFER_CTX_SPEC_VAR", "1")
  local names = env_op.list_names()
  H.ok(#names > 0, "env list_names is non-empty")
  H.ok(vim.tbl_contains(names, "BUFFER_CTX_SPEC_VAR"), "env list_names sees a freshly set var")

  -- ── sticky UTC via config ────────────────────────────────────────────────
  local timestamp = require("buffer_ctx.ops.timestamp")
  local utc_now = timestamp.format_timestamp("iso", true)
  H.match(utc_now, "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d$", "timestamp utc shape")
  H.eq(
    timestamp.format_timestamp("iso", true),
    os.date("!%Y-%m-%dT%H:%M:%S"),
    "timestamp utc matches os.date UTC"
  )

  -- ── filepath nvim_module alias ───────────────────────────────────────────
  -- The alias lives in the dispatch layer, so drive it the way a user would.
  H.scratch(cwd .. "/lua/aliased/mod.lua")
  vim.fn.setreg('"', "")
  require("buffer_ctx.commands")._dispatch("filepath", { "nvim_module" }, "clip")
  local aliased = vim.fn.getreg('"')
  vim.fn.setreg('"', "")
  require("buffer_ctx.commands")._dispatch("module", {}, "clip")
  H.eq(aliased, vim.fn.getreg('"'), "filepath nvim_module matches the module subcommand")
end
