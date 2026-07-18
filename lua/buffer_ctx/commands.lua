---@module 'buffer_ctx.commands'
---@brief :Insert / :Copy dispatch — resolves a subcommand to an ops/* handler
--- and routes the result into a sink (cursor insert or clipboard copy).
---@see buffer_ctx.format for the sibling :Format command tree
---@see buffer_ctx.mark for the sibling :Mark command tree
---@see buffer_ctx.util.cursor insert sink
---@see buffer_ctx.util.clip copy sink

local M = {}

local notify = require("buffer_ctx.util.notify")
local cursor = require("buffer_ctx.util.cursor")
local clip = require("buffer_ctx.util.clip")
local filepath = require("buffer_ctx.ops.filepath")
local module_op = require("buffer_ctx.ops.module")
local timestamp = require("buffer_ctx.ops.timestamp")
local uuid_op = require("buffer_ctx.ops.uuid")
local annotation = require("buffer_ctx.ops.annotation")
local location = require("buffer_ctx.ops.location")
local env_op = require("buffer_ctx.ops.env")
local boiler = require("buffer_ctx.ops.boilerplate")
local snippet = require("buffer_ctx.ops.snippet")
local git_op = require("buffer_ctx.ops.git")
local bufinfo = require("buffer_ctx.ops.bufinfo")

-- Route a result to the chosen sink
local function sink_text(text, sink)
  if sink == "clip" then
    clip.copy(text)
  else
    cursor.insert_text(text)
  end
end

local function sink_lines(lines, sink)
  if sink == "clip" then
    clip.copy(table.concat(lines, "\n"))
  else
    cursor.insert_lines(lines)
  end
end

---Read a config sub-table without hard-failing when config isn't set up yet
---@param key string
---@return table
local function cfg(key)
  local ok, config = pcall(require, "buffer_ctx.config")
  if not ok then
    return {}
  end
  local active = config.get() or {}
  local section = active[key]
  return type(section) == "table" and section or {}
end

-- Dispatch table: subcmd → function(fargs, sink, ctx)
-- ctx carries the command range ({ line1, line2 }) when one was given.
local DISPATCH = {
  filepath = function(fargs, sink)
    -- "nvim_module" is an alias for the module subcommand, so that
    -- `:Copy filepath nvim_module` and `:Copy module` agree.
    if fargs[1] and fargs[1]:lower() == "nvim_module" then
      local result, err = module_op.get_statement(module_op.parse_args({}))
      if not result then
        notify.error(err or "module failed")
        return
      end
      sink_text(result, sink)
      return
    end
    local opts = filepath.parse_args(fargs)
    local result, err = filepath.get_path(opts)
    if not result then
      notify.error(err or "filepath failed")
      return
    end
    sink_text(result, sink)
  end,

  filename = function(fargs, sink)
    local no_ext = fargs[1] and fargs[1]:lower() == "noext"
    local result, err = filepath.get_filename(no_ext)
    if not result then
      notify.error(err or "filename failed")
      return
    end
    sink_text(result, sink)
  end,

  module = function(fargs, sink)
    local style = module_op.parse_args(fargs)
    local result, err = module_op.get_statement(style)
    if not result then
      notify.error(err or "module failed")
      return
    end
    sink_text(result, sink)
  end,

  timestamp = function(fargs, sink)
    local fmt, utc = timestamp.parse_args(fargs)
    -- Sticky config UTC; an explicit --utc can only turn it on, never off.
    local result = timestamp.format_timestamp(fmt, utc or cfg("timestamp").utc == true)
    sink_text(result, sink)
  end,

  date = function(_, sink)
    local result = timestamp.format_timestamp("iso-date", cfg("timestamp").utc == true)
    sink_text(result, sink)
  end,

  git = function(fargs, sink)
    local mode = git_op.parse_args(fargs)
    local result, err = git_op.get(mode)
    if not result then
      notify.error(err or "git failed")
      return
    end
    sink_text(result, sink)
  end,

  linecount = function(_, sink)
    local result, err = bufinfo.get_linecount()
    if not result then
      notify.error(err or "linecount failed")
      return
    end
    sink_text(result, sink)
  end,

  bufnr = function(_, sink)
    local result, err = bufinfo.get_bufnr()
    if not result then
      notify.error(err or "bufnr failed")
      return
    end
    sink_text(result, sink)
  end,

  snippet = function(fargs, sink)
    local name = fargs[1]
    if not name or name == "" then
      local keys = snippet.list_keys()
      if #keys == 0 then
        notify.error("no snippets configured (snippets = { paths = {…} })")
        return
      end
      vim.ui.select(keys, { prompt = "Snippet:" }, function(choice)
        if not choice then
          return
        end
        local lines, err = snippet.get(choice)
        if not lines then
          notify.error(err or "snippet failed")
          return
        end
        sink_lines(lines, sink)
      end)
      return
    end
    local lines, err = snippet.get(name)
    if not lines then
      notify.error(err or "snippet failed")
      return
    end
    sink_lines(lines, sink)
  end,

  uuid = function(fargs, sink)
    local fmt = uuid_op.parse_args(fargs)
    sink_text(uuid_op.get(fmt), sink)
  end,

  annotation = function(fargs, sink)
    local ann_type = table.remove(fargs, 1) or "module"
    local result, err = annotation.get(ann_type, fargs)
    if not result then
      notify.error(err or "annotation failed")
      return
    end
    if type(result) == "table" then
      sink_lines(result, sink)
    else
      sink_text(result, sink)
    end
  end,

  location = function(fargs, sink, ctx)
    local mode, want_range = location.parse_args(fargs)
    local result, err
    if want_range then
      result, err = location.get_range(mode, ctx and ctx.line1, ctx and ctx.line2)
    else
      result, err = location.get(mode)
    end
    if not result then
      notify.error(err or "location failed")
      return
    end
    sink_text(result, sink)
  end,

  env = function(fargs, sink)
    local var = fargs[1]
    local result, err = env_op.get(var)
    if not result then
      notify.error(err or "env failed")
      return
    end
    sink_text(result, sink)
  end,

  boilerplate = function(fargs, sink)
    local key = fargs[1]
    local name = fargs[2]
    if not key or key == "" then
      -- No template given: pick interactively rather than erroring out, so the
      -- feature is usable without relying on tab completion.
      local keys = boiler.list_keys()
      local descs = boiler.describe()
      vim.ui.select(keys, {
        prompt = "Boilerplate template:",
        format_item = function(item)
          return string.format("%-22s %s", item, descs[item] or "")
        end,
      }, function(choice)
        if not choice then
          return
        end
        local lines, err = boiler.get(choice, nil)
        if not lines then
          notify.error(err or "boilerplate failed")
          return
        end
        sink_lines(lines, sink)
      end)
      return
    end
    local lines, err = boiler.get(key, name)
    if not lines then
      notify.error(err or "boilerplate failed")
      return
    end
    sink_lines(lines, sink)
  end,
}

local SUBCMDS = {
  "filepath",
  "filename",
  "module",
  "timestamp",
  "date",
  "uuid",
  "annotation",
  "boilerplate",
  "snippet",
  "location",
  "env",
  "git",
  "linecount",
  "bufnr",
}

local ANNOTATION_TYPES = {
  "module",
  "class",
  "field",
  "param",
  "return",
  "function",
  "alias",
  "overload",
  "diagnostic",
  "deprecated",
}

local SUBCMD_ARGS = {
  filepath = {
    "relative",
    "absolute",
    "cwd",
    "abs",
    "nvim",
    "lua",
    "unix",
    "win",
    "system",
    "0",
    "1",
    "2",
    "3",
  },
  filename = { "noext" },
  module = { "require", "lua_ls", "js", "c", "generic" },
  git = { "hash", "short", "branch", "tag" },
  timestamp = {
    "iso",
    "iso-date",
    "iso-time",
    "unix",
    "human",
    "short",
    "log",
    "filename",
    "--utc",
  },
  uuid = { "standard", "compact", "upper", "braced" },
  annotation = ANNOTATION_TYPES,
  location = { "cwd", "abs", "lua", "range" },
  boilerplate = nil, -- populated lazily from boiler.list_keys()
  snippet = nil, -- populated lazily from snippet.list_keys()
  env = nil, -- populated lazily from env_op.list_names()
}

local function filter(list, lead)
  if lead == "" then
    return list
  end
  local out = {}
  for _, v in ipairs(list) do
    if v:sub(1, #lead) == lead then
      out[#out + 1] = v
    end
  end
  return out
end

local function complete(arglead, cmdline, _)
  -- Count committed tokens (space-separated, excluding trailing space or current token)
  local tokens = {}
  for t in cmdline:gmatch("%S+") do
    tokens[#tokens + 1] = t
  end
  local trailing_space = cmdline:sub(-1) == " "
  local committed = #tokens - (trailing_space and 0 or 1) - 1 -- subtract command itself

  if committed <= 0 then
    return filter(SUBCMDS, arglead)
  end

  local subcmd = tokens[2]
  local arg_idx = committed -- 1 = completing first arg after subcmd

  if subcmd == "boilerplate" then
    if arg_idx == 1 then
      return filter(boiler.list_keys(), arglead)
    end
    return {}
  end

  if subcmd == "snippet" then
    if arg_idx == 1 then
      return filter(snippet.list_keys(), arglead)
    end
    return {}
  end

  if subcmd == "env" then
    if arg_idx == 1 then
      return filter(env_op.list_names(), arglead)
    end
    return {}
  end

  if subcmd == "annotation" then
    if arg_idx == 1 then
      return filter(ANNOTATION_TYPES, arglead)
    end
    return {}
  end

  local args = SUBCMD_ARGS[subcmd]
  if args and arg_idx == 1 then
    return filter(args, arglead)
  end

  return {}
end

local function make_handler(sink)
  return function(a)
    local subcmd = a.fargs[1]
    if not subcmd or subcmd == "" then
      notify.error("usage: {subcmd} [args…]  (tab for subcommands)")
      return
    end
    local handler = DISPATCH[subcmd]
    if not handler then
      notify.error("unknown subcommand: " .. subcmd)
      return
    end
    local fargs = vim.list_slice(a.fargs, 2)
    -- a.range is 0 when the user gave no range; only then are line1/line2
    -- meaningless (both default to the cursor line).
    local ctx = (a.range and a.range > 0) and { line1 = a.line1, line2 = a.line2 } or nil
    handler(fargs, sink, ctx)
  end
end

---Call a subcommand directly from Lua
---@param subcmd string
---@param fargs string[]
---@param sink BufferCtx.Sink
---@param ctx? { line1: integer, line2: integer }
function M._dispatch(subcmd, fargs, sink, ctx)
  local handler = DISPATCH[subcmd]
  if not handler then
    notify.error("unknown subcommand: " .. subcmd)
    return
  end
  handler(fargs, sink, ctx)
end

function M.register()
  -- range = true so `:'<,'>Copy location range` receives the selection; it
  -- stays optional, every other subcommand ignores it.
  vim.api.nvim_create_user_command("Insert", make_handler("cursor"), {
    nargs = "+",
    range = true,
    complete = complete,
    desc = "Insert context text at cursor",
  })
  vim.api.nvim_create_user_command("Copy", make_handler("clip"), {
    nargs = "+",
    range = true,
    complete = complete,
    desc = "Copy context text to clipboard",
  })
end

return M
