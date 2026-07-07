---@module 'buffer_ctx.commands'
local M = {}

local notify    = require("buffer_ctx.util.notify")
local cursor    = require("buffer_ctx.util.cursor")
local clip      = require("buffer_ctx.util.clip")
local filepath  = require("buffer_ctx.ops.filepath")
local module_op = require("buffer_ctx.ops.module")
local timestamp = require("buffer_ctx.ops.timestamp")
local uuid_op   = require("buffer_ctx.ops.uuid")
local annotation= require("buffer_ctx.ops.annotation")
local location  = require("buffer_ctx.ops.location")
local env_op    = require("buffer_ctx.ops.env")
local boiler    = require("buffer_ctx.ops.boilerplate")

-- Route a result to the chosen sink
local function sink_text(text, sink)
  if sink == "clip" then clip.copy(text) else cursor.insert_text(text) end
end

local function sink_lines(lines, sink)
  if sink == "clip" then
    clip.copy(table.concat(lines, "\n"))
  else
    cursor.insert_lines(lines)
  end
end

-- Dispatch table: subcmd → function(fargs, sink)
local DISPATCH = {
  filepath = function(fargs, sink)
    local opts = filepath.parse_args(fargs)
    local result, err = filepath.get_path(opts)
    if not result then notify.error(err or "filepath failed"); return end
    sink_text(result, sink)
  end,

  filename = function(fargs, sink)
    local no_ext = fargs[1] and fargs[1]:lower() == "noext"
    local result, err = filepath.get_filename(no_ext)
    if not result then notify.error(err or "filename failed"); return end
    sink_text(result, sink)
  end,

  module = function(fargs, sink)
    local style = module_op.parse_args(fargs)
    local result, err = module_op.get_statement(style)
    if not result then notify.error(err or "module failed"); return end
    sink_text(result, sink)
  end,

  timestamp = function(fargs, sink)
    local fmt, utc = timestamp.parse_args(fargs)
    local result = timestamp.format_timestamp(fmt, utc)
    sink_text(result, sink)
  end,

  uuid = function(fargs, sink)
    local fmt = uuid_op.parse_args(fargs)
    sink_text(uuid_op.get(fmt), sink)
  end,

  annotation = function(fargs, sink)
    local ann_type = table.remove(fargs, 1) or "module"
    local result, err = annotation.get(ann_type, fargs)
    if not result then notify.error(err or "annotation failed"); return end
    if type(result) == "table" then
      sink_lines(result, sink)
    else
      sink_text(result, sink)
    end
  end,

  location = function(fargs, sink)
    local mode = location.parse_args(fargs)
    local result, err = location.get(mode)
    if not result then notify.error(err or "location failed"); return end
    sink_text(result, sink)
  end,

  env = function(fargs, sink)
    local var = fargs[1]
    local result, err = env_op.get(var)
    if not result then notify.error(err or "env failed"); return end
    sink_text(result, sink)
  end,

  boilerplate = function(fargs, sink)
    local key  = fargs[1]
    local name = fargs[2]
    if not key or key == "" then
      notify.error("usage: boilerplate {template} [name]")
      return
    end
    local lines, err = boiler.get(key, name)
    if not lines then notify.error(err or "boilerplate failed"); return end
    sink_lines(lines, sink)
  end,
}

local SUBCMDS = {
  "filepath", "filename", "module", "timestamp", "uuid",
  "annotation", "boilerplate", "location", "env",
}

local SUBCMD_ARGS = {
  filepath   = { "relative", "absolute", "cwd", "abs", "nvim", "lua", "unix", "win", "system", "0", "1", "2", "3" },
  filename   = { "noext" },
  module     = { "require", "lua_ls", "js", "c", "generic" },
  timestamp  = { "iso", "iso-date", "iso-time", "unix", "human", "short", "log", "filename", "--utc" },
  uuid       = { "standard", "compact", "upper", "braced" },
  annotation = { "module", "class", "field", "param", "return", "function", "alias" },
  location   = { "cwd", "abs", "lua" },
  boilerplate= nil, -- populated lazily from boiler.list_keys()
  env        = {},
}

local function filter(list, lead)
  if lead == "" then return list end
  local out = {}
  for _, v in ipairs(list) do
    if v:sub(1, #lead) == lead then out[#out + 1] = v end
  end
  return out
end

local function complete(arglead, cmdline, _)
  -- Count committed tokens (space-separated, excluding trailing space or current token)
  local tokens = {}
  for t in cmdline:gmatch("%S+") do tokens[#tokens + 1] = t end
  local trailing_space = cmdline:sub(-1) == " "
  local committed = #tokens - (trailing_space and 0 or 1) - 1  -- subtract command itself

  if committed <= 0 then
    return filter(SUBCMDS, arglead)
  end

  local subcmd = tokens[2]
  local arg_idx = committed  -- 1 = completing first arg after subcmd

  if subcmd == "boilerplate" then
    if arg_idx == 1 then return filter(boiler.list_keys(), arglead) end
    return {}
  end

  if subcmd == "annotation" then
    if arg_idx == 1 then
      return filter({ "module", "class", "field", "param", "return", "function", "alias" }, arglead)
    end
    return {}
  end

  local args = SUBCMD_ARGS[subcmd]
  if args and arg_idx == 1 then return filter(args, arglead) end

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
    handler(fargs, sink)
  end
end

---Call a subcommand directly from Lua
---@param subcmd string
---@param fargs string[]
---@param sink BufferCtx.Sink
function M._dispatch(subcmd, fargs, sink)
  local handler = DISPATCH[subcmd]
  if not handler then notify.error("unknown subcommand: " .. subcmd); return end
  handler(fargs, sink)
end

function M.register()
  vim.api.nvim_create_user_command("Insert", make_handler("cursor"), {
    nargs    = "+",
    complete = complete,
    desc     = "Insert context text at cursor",
  })
  vim.api.nvim_create_user_command("Copy", make_handler("clip"), {
    nargs    = "+",
    complete = complete,
    desc     = "Copy context text to clipboard",
  })
end

return M
