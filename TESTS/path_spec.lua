-- TESTS/path_spec.lua — buffer_ctx.util.path pure functions.

return function(H)
  local pu = require("buffer_ctx.util.path")

  -- get_module_path
  H.eq(
    pu.get_module_path("/home/user/plugin/lua/foo/bar/init.lua"),
    "foo.bar",
    "get_module_path init.lua"
  )
  H.eq(
    pu.get_module_path("/home/user/plugin/lua/foo/bar.lua"),
    "foo.bar",
    "get_module_path plain file"
  )
  H.eq(
    pu.get_module_path("C:\\repos\\x\\lua\\a\\b\\init.lua"),
    "a.b",
    "get_module_path backslashes"
  )
  H.eq(pu.get_module_path("/home/user/README.md"), nil, "get_module_path no /lua/ segment")
  -- Regression: gsub returns (string, count); the count must not leak out.
  H.eq(
    select("#", pu.get_module_path("/x/lua/a/b.lua")),
    1,
    "get_module_path returns exactly one value"
  )

  -- normalize_sep
  H.eq(pu.normalize_sep("a\\b/c"), "a/b/c", "normalize_sep default")
  H.eq(pu.normalize_sep("a/b\\c", "\\"), "a\\b\\c", "normalize_sep explicit sep")

  -- pick_depth
  H.eq(table.concat(pu.pick_depth("a/b/c/d", 2), "/"), "c/d", "pick_depth 2")
  H.eq(table.concat(pu.pick_depth("a/b/c/d", 1), "/"), "d", "pick_depth 1")
  H.eq(table.concat(pu.pick_depth("a\\b\\c", 2), "/"), "b/c", "pick_depth backslashes")

  -- relative_to_cwd (built from actual cwd so the test is cwd-independent)
  local cwd = vim.fn.getcwd()
  local abs = cwd .. "/lua/foo/bar.lua"
  H.eq(pu.relative_to_cwd(abs), "lua/foo/bar.lua", "relative_to_cwd strips cwd")

  -- is_inside_nvim_config
  local config = vim.fn.stdpath("config")
  H.ok(pu.is_inside_nvim_config(config .. "/lua/foo.lua"), "is_inside_nvim_config: inside")
  H.ok(
    not pu.is_inside_nvim_config("/definitely/not/nvim/config/foo.lua"),
    "is_inside_nvim_config: outside"
  )

  -- strip_root: the shared root-matching helper behind mode="nvim"/"repos"/
  -- "env" in ops/filepath.lua (and is_inside_nvim_config above).
  H.eq(pu.strip_root(cwd .. "/lua/foo.lua", cwd), "lua/foo.lua", "strip_root: basic match")
  local _, root_len = pu.strip_root(cwd .. "/lua/foo.lua", cwd)
  H.eq(root_len, #cwd, "strip_root: reports the matched root's length")
  H.eq(pu.strip_root(cwd, cwd), "", "strip_root: exact match returns an empty rest")
  H.eq(
    pu.strip_root(cwd .. "/lua/foo.lua", "/definitely/not/it"),
    nil,
    "strip_root: no match returns nil"
  )
  H.eq(pu.strip_root(cwd .. "/lua/foo.lua", nil), nil, "strip_root: nil root returns nil")
  H.eq(pu.strip_root(cwd .. "/lua/foo.lua", ""), nil, "strip_root: empty root returns nil")
  H.eq(
    pu.strip_root(cwd .. "/lua/foo.lua", cwd .. "/"),
    "lua/foo.lua",
    "strip_root: a trailing separator on root is ignored"
  )
  if vim.fn.has("win32") == 1 then
    -- Windows compares paths case-insensitively; $REPOS_DIR/stdpath("config")
    -- can differ in case (e.g. drive letter) from what fnamemodify(":p")
    -- reports for the same file.
    H.eq(
      pu.strip_root(cwd .. "/lua/foo.lua", cwd:upper()),
      "lua/foo.lua",
      "strip_root: case-insensitive match on Windows"
    )
  end
end
