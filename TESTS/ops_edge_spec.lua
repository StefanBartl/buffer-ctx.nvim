-- TESTS/ops_edge_spec.lua — error/edge branches across ops/* that the happy
-- paths in ops_spec.lua and features_spec.lua don't reach: every
-- buffer_ctx.ops.annotation type (including the fn.input-driven interactive
-- fallbacks), buffer_ctx.ops.git's non-happy modes (exercised against real
-- temp git repositories rather than mocked output), and the unnamed-buffer /
-- outside-/lua// / malformed-input error paths of filepath, location,
-- module and snippet.

return function(H)
  local ann = require("buffer_ctx.ops.annotation")

  -- ── annotation: types driven by explicit args (no fn.input prompt) ────────
  H.eq(ann.get("class", { "Widget" }), "---@class Widget", "annotation class with explicit name")
  H.eq(
    ann.get("field", { "count", "integer" }),
    "---@field count integer",
    "annotation field with explicit name+type"
  )
  H.eq(
    ann.get("field", { "count", "" }),
    "---@field count any",
    "annotation field defaults type to 'any' when given empty"
  )
  H.eq(
    ann.get("param", { "opts", "table" }),
    "---@param opts table",
    "annotation param with explicit name+type"
  )
  H.eq(
    ann.get("return", { "boolean" }),
    "---@return boolean",
    "annotation return with explicit type"
  )
  H.eq(
    ann.get("alias", { "Mode", "string" }),
    "---@alias Mode string",
    "annotation alias with explicit name+type"
  )

  -- ── annotation: fn.input-driven fallbacks (args omitted) ──────────────────
  local original_input = vim.fn.input
  vim.fn.input = function(prompt)
    if prompt:find("Class name") then
      return "Prompted"
    elseif prompt:find("Field name") then
      return "field_name"
    elseif prompt:find("Field type") then
      return ""
    elseif prompt:find("Param name") then
      return "arg1"
    elseif prompt:find("Param type") then
      return ""
    elseif prompt:find("Return type") then
      return ""
    elseif prompt:find("Alias name") then
      return "AliasName"
    elseif prompt:find("Alias type") then
      return ""
    end
    return ""
  end

  H.eq(ann.get("class", {}), "---@class Prompted", "annotation class falls back to fn.input")
  H.eq(
    ann.get("field", {}),
    "---@field field_name any",
    "annotation field falls back to fn.input, defaults type to 'any'"
  )
  H.eq(
    ann.get("param", {}),
    "---@param arg1 any",
    "annotation param falls back to fn.input, defaults type to 'any'"
  )
  local ret_result = ann.get("return", {})
  H.eq(ret_result, "---@return any", "annotation return falls back to fn.input, defaults to 'any'")
  H.eq(
    ann.get("alias", {}),
    "---@alias AliasName string",
    "annotation alias falls back to fn.input, defaults type to 'string'"
  )

  -- Required-field guards: an empty fn.input answer is still "no value".
  vim.fn.input = function()
    return ""
  end
  local _, class_err = ann.get("class", {})
  H.ok(class_err ~= nil, "annotation class requires a non-empty name")
  local _, field_err = ann.get("field", {})
  H.ok(field_err ~= nil, "annotation field requires a non-empty name")
  local _, param_err = ann.get("param", {})
  H.ok(param_err ~= nil, "annotation param requires a non-empty name")
  local _, alias_err = ann.get("alias", {})
  H.ok(alias_err ~= nil, "annotation alias requires a non-empty name")

  -- ── annotation: "function" interactive multi-line dialog ──────────────────
  local input_calls = 0
  local param_names = { "a", "b" }
  vim.fn.input = function(prompt)
    input_calls = input_calls + 1
    if prompt:find("Function description") then
      return "does a thing"
    elseif prompt:find("Param name") then
      local n = table.remove(param_names, 1)
      return n or ""
    elseif prompt:find("type:%s*$") then
      return "any"
    elseif prompt:find("Return type") then
      return "boolean"
    end
    return ""
  end
  local fn_lines, fn_err = ann.get("function", {})
  H.eq(fn_err, nil, "annotation function: no error")
  H.eq(fn_lines[1], "---does a thing", "annotation function: description line")
  H.eq(fn_lines[2], "---@param a any", "annotation function: first param line")
  H.eq(fn_lines[3], "---@param b any", "annotation function: second param line")
  H.eq(fn_lines[4], "---@return boolean", "annotation function: return line")

  -- Nothing entered at all → no annotation generated.
  vim.fn.input = function()
    return ""
  end
  local empty_lines, empty_err = ann.get("function", {})
  H.eq(empty_lines, nil, "annotation function with no input produces nothing")
  H.ok(empty_err ~= nil, "annotation function with no input reports an error")

  vim.fn.input = original_input

  -- ── annotation: module type ────────────────────────────────────────────────
  H.scratch(nil)
  local _, unnamed_err = ann.get("module", {})
  H.ok(unnamed_err ~= nil, "annotation module on an unnamed buffer errors")

  H.scratch(vim.fn.getcwd() .. "/README-ann.md")
  local _, outside_err = ann.get("module", {})
  H.ok(outside_err ~= nil, "annotation module outside a /lua/ directory errors")

  H.scratch(vim.fn.getcwd() .. "/lua/anntest/thing.lua")
  H.eq(
    ann.get("module", {}),
    "---@module 'anntest.thing'",
    "annotation module derives the path from the current buffer"
  )

  -- ── git: repo_dir() falls back to cwd on an unnamed buffer ────────────────
  local git = require("buffer_ctx.ops.git")
  H.scratch(nil)
  if vim.fn.executable("git") == 1 then
    local sha, sha_err = git.get("hash")
    H.eq(sha_err, nil, "git.get on an unnamed buffer falls back to cwd (no error)")
    H.match(sha or "", "^%x+$", "git.get on an unnamed buffer still returns a hex sha")
  end

  -- ── git: executable missing ────────────────────────────────────────────────
  local original_executable = vim.fn.executable
  vim.fn.executable = function()
    return 0
  end
  local _, exec_err = git.get("hash")
  H.match(exec_err, "not found in PATH", "git.get reports a missing git executable")
  vim.fn.executable = original_executable

  -- ── git: tag mode (always succeeds via --always, even with no tags) ──────
  if vim.fn.executable("git") == 1 then
    local tag, tag_err = git.get("tag")
    H.eq(tag_err, nil, "git.get('tag') succeeds via --always")
    H.ok(tag ~= nil and tag ~= "", "git.get('tag') returns a non-empty description")

    -- ── git: branch mode on a real (non-detached) checkout ──────────────────
    local branch, branch_err = git.get("branch")
    H.eq(branch_err, nil, "git.get('branch') succeeds on a normal checkout")
    H.ok(branch ~= "HEAD", "git.get('branch') is not the literal HEAD placeholder")
  end

  -- ── git: real temp repos for the non-repo and detached-HEAD paths ─────────
  if vim.fn.executable("git") == 1 then
    local non_repo_dir = vim.fn.tempname()
    vim.fn.mkdir(non_repo_dir, "p")
    H.scratch(non_repo_dir .. "/scratch.txt")
    local _, non_repo_err = git.get("short")
    H.match(
      non_repo_err or "",
      "^git: ",
      "git.get outside any repository reports git's own failure"
    )
    vim.fn.delete(non_repo_dir, "rf")

    local repo_dir = vim.fn.tempname()
    vim.fn.mkdir(repo_dir, "p")
    vim.fn.systemlist({ "git", "-C", repo_dir, "init", "-q" })
    vim.fn.systemlist({ "git", "-C", repo_dir, "config", "user.email", "test@example.com" })
    vim.fn.systemlist({ "git", "-C", repo_dir, "config", "user.name", "Test" })
    vim.fn.writefile({ "hello" }, repo_dir .. "/file.txt")
    vim.fn.systemlist({ "git", "-C", repo_dir, "add", "." })
    vim.fn.systemlist({ "git", "-C", repo_dir, "commit", "-q", "-m", "init" })
    local sha = vim.fn.systemlist({ "git", "-C", repo_dir, "rev-parse", "HEAD" })[1]
    vim.fn.systemlist({ "git", "-C", repo_dir, "checkout", "-q", sha })

    H.scratch(repo_dir .. "/file.txt")
    local _, detached_err = git.get("branch")
    H.match(detached_err or "", "detached HEAD", "git.get('branch') reports a detached HEAD")

    vim.fn.delete(repo_dir, "rf")
  end

  -- ── filepath: mode/format branches not hit by ops_spec.lua's happy path ──
  local filepath = require("buffer_ctx.ops.filepath")
  local cwd = vim.fn.getcwd()

  H.scratch(cwd .. "/lua/fp/thing.lua")
  local abs_result = filepath.get_path({ mode = "abs", format = "unix" })
  H.match(abs_result, "lua/fp/thing%.lua$", "filepath mode=abs ends with the buffer's own path")
  H.ok(
    abs_result:match("^%a:[/\\]") or abs_result:sub(1, 1) == "/",
    "filepath mode=abs is absolute"
  )

  local win_result = filepath.get_path({ mode = "cwd", format = "win" })
  H.eq(win_result, "lua\\fp\\thing.lua", "filepath format=win joins segments with backslashes")

  local system_result = filepath.get_path({ mode = "cwd", format = "system" })
  local sep = package.config:sub(1, 1)
  H.eq(
    system_result,
    table.concat({ "lua", "fp", "thing.lua" }, sep),
    "filepath format=system joins with the host's own path separator"
  )

  local depth_result = filepath.get_path({ mode = "cwd", format = "unix", depth = 1 })
  H.eq(depth_result, "fp/thing.lua", "filepath depth=1 keeps only the last 2 segments")

  -- format=lua with no "lua" segment in the path: nothing is stripped, only
  -- the extension comes off the last segment.
  H.scratch(cwd .. "/src/foo/bar.lua")
  H.eq(
    filepath.get_path({ mode = "cwd", format = "lua" }),
    "src.foo.bar",
    "filepath format=lua with no /lua/ segment only strips the extension"
  )

  -- format=lua where the "lua" segment is the last one: nothing follows it.
  H.scratch(cwd .. "/somewhere/lua")
  H.eq(
    filepath.get_path({ mode = "cwd", format = "lua" }),
    "",
    "filepath format=lua with 'lua' as the final segment yields an empty string"
  )

  -- mode=nvim inside the Neovim config directory: format=lua is forced to
  -- unix (a config-relative path is never a dotted module name).
  local nvim_config = vim.fn.stdpath("config"):gsub("\\", "/")
  H.scratch(nvim_config .. "/lua/plugin/x.lua")
  H.eq(
    filepath.get_path({ mode = "nvim", format = "lua" }),
    "lua/plugin/x.lua",
    "filepath mode=nvim inside the config dir forces format to unix"
  )

  -- mode=nvim outside the config directory falls back to cwd-relative.
  H.scratch(cwd .. "/lua/fp3/thing.lua")
  H.eq(
    filepath.get_path({ mode = "nvim", format = "unix" }),
    filepath.get_path({ mode = "cwd", format = "unix" }),
    "filepath mode=nvim outside the config dir falls back to cwd-relative"
  )

  -- mode=repos inside $REPOS_DIR, outside it, and with the variable unset.
  do
    local saved_repos_dir = vim.env.REPOS_DIR

    vim.env.REPOS_DIR = cwd .. "/reposroot"
    H.scratch(cwd .. "/reposroot/plugin.nvim/lua/init.lua")
    H.eq(
      filepath.get_path({ mode = "repos", format = "unix" }),
      "plugin.nvim/lua/init.lua",
      "filepath mode=repos inside $REPOS_DIR strips the repos-root prefix"
    )

    H.scratch(cwd .. "/lua/fp4/thing.lua")
    H.eq(
      filepath.get_path({ mode = "repos", format = "unix" }),
      filepath.get_path({ mode = "cwd", format = "unix" }),
      "filepath mode=repos outside $REPOS_DIR falls back to cwd-relative"
    )

    vim.env.REPOS_DIR = nil
    local _, repos_unset_err = filepath.get_path({ mode = "repos", format = "unix" })
    H.ok(repos_unset_err ~= nil, "filepath mode=repos errors when $REPOS_DIR is unset")

    vim.env.REPOS_DIR = saved_repos_dir
  end

  -- mode=env folds whichever of $REPOS_DIR / $NVIM_CONFIG_DIR matches into a
  -- literal "$VAR/..." prefix (longest root wins); falls back to cwd-relative
  -- like repos/nvim do when neither matches, and keeps working with only one
  -- of the two roots available.
  do
    local saved_repos_dir = vim.env.REPOS_DIR
    vim.env.REPOS_DIR = cwd .. "/reposroot"

    H.scratch(cwd .. "/reposroot/envmode.nvim/lua/init.lua")
    H.eq(
      filepath.get_path({ mode = "env", format = "unix" }),
      "$REPOS_DIR/envmode.nvim/lua/init.lua",
      "filepath mode=env inside $REPOS_DIR folds the repos-root into $REPOS_DIR"
    )

    H.scratch(nvim_config .. "/lua/envmode/x.lua")
    H.eq(
      filepath.get_path({ mode = "env", format = "lua" }),
      "$NVIM_CONFIG_DIR/lua/envmode/x.lua",
      "filepath mode=env inside the config dir folds into $NVIM_CONFIG_DIR and forces format to unix"
    )

    H.scratch(cwd .. "/lua/fp5/thing.lua")
    H.eq(
      filepath.get_path({ mode = "env", format = "unix" }),
      filepath.get_path({ mode = "cwd", format = "unix" }),
      "filepath mode=env outside both roots falls back to cwd-relative"
    )

    vim.env.REPOS_DIR = nil
    H.scratch(nvim_config .. "/lua/plugin/y.lua")
    H.eq(
      filepath.get_path({ mode = "env", format = "unix" }),
      "$NVIM_CONFIG_DIR/lua/plugin/y.lua",
      "filepath mode=env still folds $NVIM_CONFIG_DIR when $REPOS_DIR is unset"
    )

    vim.env.REPOS_DIR = saved_repos_dir
  end

  H.scratch(nil)
  local _, path_unnamed_err = filepath.get_path({ mode = "cwd", format = "unix" })
  H.ok(path_unnamed_err ~= nil, "filepath.get_path on an unnamed buffer errors")
  local _, filename_unnamed_err = filepath.get_filename()
  H.ok(filename_unnamed_err ~= nil, "filepath.get_filename on an unnamed buffer errors")

  -- ── location: unnamed buffer, "lua" mode, and get_range's fallbacks ───────
  local location = require("buffer_ctx.ops.location")

  H.scratch(nil)
  local _, loc_unnamed_err = location.get("cwd")
  H.ok(loc_unnamed_err ~= nil, "location.get on an unnamed buffer errors")
  local _, range_unnamed_err = location.get_range("cwd", 1, 1)
  H.ok(range_unnamed_err ~= nil, "location.get_range on an unnamed buffer errors")

  H.scratch(cwd .. "/lua/loc2/mod.lua")
  H.eq(location.get("lua"), "loc2.mod:1", "location.get mode=lua uses the dotted module path")

  H.scratch(cwd .. "/notlua/mod.txt")
  H.match(
    location.get("lua"),
    "^notlua/mod%.txt:1$",
    "location.get mode=lua falls back to cwd-relative outside /lua/"
  )

  -- get_range with no explicit lines and no visual marks falls back to the
  -- cursor line (a fresh buffer's cursor starts at line 1).
  H.scratch(cwd .. "/lua/loc3/mod.lua")
  H.eq(
    location.get_range("cwd", nil, nil),
    "lua/loc3/mod.lua:1",
    "location.get_range with no args and no marks falls back to the cursor line"
  )

  -- get_range falls back to the last visual selection only when no explicit
  -- range was given at all (both nil) -- an explicit single-line range
  -- (line1 == line2, both non-nil) must be honoured as-is, not overridden by
  -- a stale visual selection elsewhere in the buffer (ERR-10: "no argument"
  -- and "argument given" must not collapse onto the same result).
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a", "b", "c", "d", "e" })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.cmd("normal! Vjj\27") -- visually select lines 2-4, then leave visual mode
  H.eq(
    location.get_range("cwd", nil, nil),
    "lua/loc3/mod.lua:L2-L4",
    "location.get_range falls back to the last visual selection ('<,'>) when unset"
  )
  H.eq(
    location.get_range("cwd", 42, 42),
    "lua/loc3/mod.lua:42",
    "location.get_range with an explicit single-line range ignores the stale visual selection"
  )

  -- ── module: unnamed buffer / outside /lua/ error paths ────────────────────
  local module_op = require("buffer_ctx.ops.module")

  H.scratch(nil)
  local _, mod_unnamed_err = module_op.get_module_path()
  H.ok(mod_unnamed_err ~= nil, "module.get_module_path on an unnamed buffer errors")
  local _, stmt_unnamed_err = module_op.get_statement("require")
  H.ok(stmt_unnamed_err ~= nil, "module.get_statement propagates get_module_path's error")

  H.scratch(cwd .. "/README-mod.md")
  local _, mod_outside_err = module_op.get_module_path()
  H.ok(mod_outside_err ~= nil, "module.get_module_path outside a /lua/ directory errors")

  -- ── snippet: source/file/entry error paths ────────────────────────────────
  local snippet = require("buffer_ctx.ops.snippet")

  snippet.set_sources({})
  local empty_snippets, no_sources_err = snippet.load()
  H.ok(vim.tbl_isempty(empty_snippets), "snippet.load with no sources returns an empty table")
  H.match(no_sources_err, "no snippet sources configured", "snippet.load with no sources names why")

  local _, get_empty_name_err = snippet.get("")
  H.match(get_empty_name_err, "usage:", "snippet.get with an empty name reports usage")

  do
    local missing_path = vim.fn.tempname() .. "-does-not-exist.json"
    snippet.set_sources({ missing_path })
    local _, unreadable_err = snippet.load()
    H.match(unreadable_err, "not readable", "snippet.load reports an unreadable source file")

    local empty_path = vim.fn.tempname() .. ".json"
    vim.fn.writefile({}, empty_path)
    snippet.set_sources({ empty_path })
    local _, empty_file_err = snippet.load()
    H.match(empty_file_err, "is empty", "snippet.load reports an empty source file")
    vim.fn.delete(empty_path)

    local bad_json_path = vim.fn.tempname() .. ".json"
    vim.fn.writefile({ "{ not valid json" }, bad_json_path)
    snippet.set_sources({ bad_json_path })
    local _, bad_json_err = snippet.load()
    H.match(bad_json_err, "invalid JSON", "snippet.load reports invalid JSON")
    vim.fn.delete(bad_json_path)

    local no_body_path = vim.fn.tempname() .. ".json"
    vim.fn.writefile({ '{ "NoBody": { "prefix": "nb" } }' }, no_body_path)
    snippet.set_sources({ no_body_path })
    local keys = snippet.list_keys()
    H.ok(not vim.tbl_contains(keys, "NoBody"), "snippet entries without a body are skipped")
    vim.fn.delete(no_body_path)

    local prefix_path = vim.fn.tempname() .. ".json"
    vim.fn.writefile({ '{ "Full Name": { "prefix": "fnp", "body": "x" } }' }, prefix_path)
    snippet.set_sources({ prefix_path })
    local prefix_keys = snippet.list_keys()
    H.ok(vim.tbl_contains(prefix_keys, "Full Name"), "snippet.list_keys includes the entry name")
    H.ok(vim.tbl_contains(prefix_keys, "fnp"), "snippet.list_keys also includes its prefix")
    vim.fn.delete(prefix_path)

    -- ERR-11: one healthy source must not swallow another source's error --
    -- "empty, but ok" and "non-empty, but something else broke" are not the
    -- same outcome.
    local ok_path = vim.fn.tempname() .. ".json"
    vim.fn.writefile({ '{ "Healthy": { "prefix": "hp", "body": "ok" } }' }, ok_path)
    local broken_path = vim.fn.tempname() .. ".json"
    vim.fn.writefile({ "{ not valid json" }, broken_path)
    snippet.set_sources({ ok_path, broken_path })
    local partial_snippets, partial_err = snippet.load()
    H.ok(
      not vim.tbl_isempty(partial_snippets),
      "snippet.load: the healthy source's snippets still load"
    )
    H.match(
      partial_err,
      "invalid JSON",
      "snippet.load: a sibling source's error is reported even though the result is non-empty"
    )
    vim.fn.delete(ok_path)
    vim.fn.delete(broken_path)

    -- LUA-16: JSON null in a body array decodes to vim.NIL (userdata, not
    -- Lua nil); a nested object/array is likewise not a plain text line.
    -- Both must sanitize to "", not stringify into buffer garbage.
    local nil_body_path = vim.fn.tempname() .. ".json"
    vim.fn.writefile({
      '{ "Nully": { "prefix": "nl", "body": ["keep", null, ["nested"]] } }',
    }, nil_body_path)
    snippet.set_sources({ nil_body_path })
    local nil_lines = snippet.get("Nully")
    H.eq(nil_lines[1], "keep", "snippet.get: a normal body line passes through untouched")
    H.eq(nil_lines[2], "", "snippet.get: a JSON null body line sanitizes to an empty string")
    H.eq(nil_lines[3], "", "snippet.get: a non-string (nested array) body line sanitizes to empty")
    vim.fn.delete(nil_body_path)
  end

  snippet.set_sources({})
end
