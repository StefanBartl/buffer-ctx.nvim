-- docs/TESTS/ops_spec.lua — pure-logic ops modules (module, uuid, timestamp,
-- env, location, filepath). Buffer-name-dependent ops get a scratch buffer
-- named under the actual cwd so results are deterministic without touching disk.

return function(H)
  local module_op = require("buffer_ctx.ops.module")
  local uuid_op = require("buffer_ctx.ops.uuid")
  local timestamp_op = require("buffer_ctx.ops.timestamp")
  local env_op = require("buffer_ctx.ops.env")
  local location_op = require("buffer_ctx.ops.location")
  local filepath_op = require("buffer_ctx.ops.filepath")

  local cwd = vim.fn.getcwd()

  -- module
  H.scratch(cwd .. "/lua/foo/bar.lua")
  H.eq(module_op.get_module_path(), "foo.bar", "module.get_module_path")
  H.eq(module_op.get_statement("require"), 'require("foo.bar")', "module require style")
  H.eq(module_op.get_statement("lua_ls"), "---@module 'foo.bar'", "module lua_ls style")
  H.eq(module_op.get_statement("js"), 'import "foo/bar"', "module js style")
  H.eq(module_op.get_statement("c"), '#include "foo/bar.h"', "module c style")
  H.eq(module_op.get_statement("generic"), "foo.bar", "module generic style")
  H.eq(module_op.parse_args({}), "require", "module parse_args default")
  H.eq(module_op.parse_args({ "JS" }), "js", "module parse_args lowercases")

  -- uuid
  local id = uuid_op.generate()
  H.match(
    id,
    "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$",
    "uuid v4 shape"
  )
  H.eq(#uuid_op.format(id, "compact"), 32, "uuid compact length")
  H.eq(uuid_op.format(id, "upper"), id:upper(), "uuid upper")
  H.eq(uuid_op.format(id, "braced"), "{" .. id .. "}", "uuid braced")
  H.eq(uuid_op.parse_args({}), "standard", "uuid parse_args default")
  -- Regression: gsub returns (string, count); the count must not leak out.
  H.eq(select("#", uuid_op.generate()), 1, "uuid generate returns exactly one value")
  H.eq(select("#", uuid_op.format(id, "compact")), 1, "uuid format returns exactly one value")

  -- timestamp
  H.match(timestamp_op.format_timestamp("unix"), "^%d+$", "timestamp unix is numeric")
  H.match(
    timestamp_op.format_timestamp("iso-date"),
    "^%d%d%d%d%-%d%d%-%d%d$",
    "timestamp iso-date shape"
  )
  local fmt, utc = timestamp_op.parse_args({ "short", "--utc" })
  H.eq(fmt, "short", "timestamp parse_args fmt")
  H.eq(utc, true, "timestamp parse_args utc flag")
  local fmt2, utc2 = timestamp_op.parse_args({})
  H.eq(fmt2, "iso", "timestamp parse_args default fmt")
  H.eq(utc2, false, "timestamp parse_args default utc")

  -- env
  vim.fn.setenv("BUFFER_CTX_TEST_VAR", "hello")
  H.eq(env_op.get("BUFFER_CTX_TEST_VAR"), "hello", "env.get plain name")
  H.eq(env_op.get("$BUFFER_CTX_TEST_VAR"), "hello", "env.get strips leading $")
  local val, err = env_op.get("BUFFER_CTX_DEFINITELY_UNSET_XYZ")
  H.eq(val, nil, "env.get unset var returns nil")
  H.ok(err ~= nil, "env.get unset var returns error message")

  -- location
  H.eq(location_op.parse_args({}), "cwd", "location parse_args default")
  H.eq(location_op.parse_args({ "ABS" }), "abs", "location parse_args lowercases")

  H.scratch(cwd .. "/lua/loc/test.lua")
  H.eq(
    location_op.get("cwd"),
    "lua/loc/test.lua:1",
    "location.get is forward-slashed on every platform"
  )

  -- filepath
  local opts = filepath_op.parse_args({})
  H.eq(opts.mode, "cwd", "filepath parse_args default mode")
  H.eq(opts.format, "unix", "filepath parse_args default format")
  H.eq(opts.depth, nil, "filepath parse_args default depth")

  local opts2 = filepath_op.parse_args({ "abs", "win", "2" })
  H.eq(opts2.mode, "abs", "filepath parse_args mode")
  H.eq(opts2.format, "win", "filepath parse_args format")
  H.eq(opts2.depth, 2, "filepath parse_args depth")

  H.eq(filepath_op.parse_args({ "absolute" }).mode, "abs", "filepath parse_args absolute alias")
  H.eq(filepath_op.parse_args({ "relative" }).mode, "cwd", "filepath parse_args relative alias")
  H.eq(filepath_op.parse_args({ "rel" }).mode, "cwd", "filepath parse_args rel alias")

  H.scratch(cwd .. "/lua/foo/qux.lua")
  H.eq(
    filepath_op.get_path({ mode = "cwd", format = "unix" }),
    "lua/foo/qux.lua",
    "filepath get_path unix"
  )
  H.eq(
    filepath_op.get_path({ mode = "cwd", format = "lua" }),
    "foo.qux",
    "filepath get_path lua style"
  )

  H.scratch(cwd .. "/somefile.lua")
  H.eq(filepath_op.get_filename(), "somefile.lua", "filepath get_filename with ext")
  H.eq(filepath_op.get_filename(true), "somefile", "filepath get_filename without ext")
end
