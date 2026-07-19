---@module 'buffer_ctx.format'
---@brief Unified :Format command with subcommands for buffer-ctx.nvim.
---@description
--- Available subcommands once enabled:
---   :Format column <target_col> [fill_char]
---   :Format table [header=ALIGN] [cell=ALIGN] [skip=COL] [scope=SCOPE]
---   :Format textwidth <N|max>
---   :Format filter [--remove] <pattern> ...
---   :Format enum [STYLE] [sep=SEP] [start=N] [inline=true|false]
---   :Format trim | sort [-r|-i|-n] | unique [-i] | case <mode> | indent | clear
---@see buffer_ctx.commands for the sibling :Insert / :Copy dispatch
---@see buffer_ctx.format.types for the subcommand type anchors

local M = {}

local notify = require("buffer_ctx.util.notify")

---@type table<string, table>
local subcommands = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Registry helpers
-- ─────────────────────────────────────────────────────────────────────────────

---@param name string
---@param def  table
local function register_subcommand(name, def)
  if subcommands[name] then
    notify.warn(string.format("Subcommand '%s' already registered", name))
    return
  end
  if type(def.handler) ~= "function" then
    error(string.format("Subcommand '%s': handler must be a function", name))
  end
  subcommands[name] = def
end

---@param cmdline string
---@return string|nil, string[]
local function parse_command_line(cmdline)
  local args_str = cmdline:match("^%s*Format%s+(.*)$") or cmdline:match("^%s*(.*)$") or ""
  local tokens = {}
  for token in args_str:gmatch("%S+") do
    tokens[#tokens + 1] = token
  end
  if #tokens == 0 then
    return nil, {}
  end
  local sub = tokens[1]
  local args = {}
  for i = 2, #tokens do
    args[#args + 1] = tokens[i]
  end
  return sub, args
end

---@param arg_lead  string
---@param cmdline   string
---@param cursor_pos integer
---@return string[]
local function format_complete(arg_lead, cmdline, cursor_pos)
  local sub = parse_command_line(cmdline)
  if not sub or sub == arg_lead then
    local out = {}
    for name in pairs(subcommands) do
      if vim.startswith(name, arg_lead) then
        out[#out + 1] = name
      end
    end
    table.sort(out)
    return out
  end
  local def = subcommands[sub]
  if def and type(def.complete) == "function" then
    local ok, result = pcall(def.complete, arg_lead, cmdline, cursor_pos)
    if ok and result then
      return result
    end
  end
  return {}
end

---@param opts table  nvim_create_user_command opts
local function format_handler(opts)
  local args = opts.fargs or {}
  if #args == 0 then
    notify.info(
      "Usage: :Format <subcommand> [args...]\n"
        .. "Available: "
        .. table.concat(vim.tbl_keys(subcommands), ", ")
    )
    return
  end
  local sub = args[1]
  local subargs = {}
  for i = 2, #args do
    subargs[#subargs + 1] = args[i]
  end
  local def = subcommands[sub]
  if not def then
    notify.error(
      string.format(
        "Unknown subcommand: '%s'  Available: %s",
        sub,
        table.concat(vim.tbl_keys(subcommands), ", ")
      )
    )
    return
  end
  -- opts.range is 0 when the command was invoked with no range prefix; only
  -- then are line1/line2 meaningless (both default to the cursor line).
  local ctx = (opts.range and opts.range > 0) and { line1 = opts.line1, line2 = opts.line2 } or nil
  local ok, err = pcall(def.handler, subargs, ctx)
  if not ok then
    notify.error(string.format("[%s] %s", sub, tostring(err)))
  end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Subcommand setup functions
-- ─────────────────────────────────────────────────────────────────────────────

local function setup_column_align()
  local ok, ca = pcall(require, "buffer_ctx.format.column_align")
  if not ok then
    return
  end
  register_subcommand("column", {
    handler = function(args)
      if #args == 0 then
        ca.align_interactive()
        return
      end
      local target_col = tonumber(args[1])
      if not target_col then
        notify.error("[column] Invalid target column — usage: column <N> [fill_char]")
        return
      end
      ca.align_to_column(target_col, args[2] or " ")
    end,
    complete = function()
      return {}
    end,
    nargs = "*",
    range = true,
    desc = "Align selected char to column: column <N> [fill]",
  })
end

local function setup_table()
  local ok, tbl = pcall(require, "buffer_ctx.format.table_fmt")
  if not ok then
    return
  end
  tbl.setup(register_subcommand, notify)
end

local function setup_text_width()
  local ok, tw = pcall(require, "buffer_ctx.format.text_width")
  if not ok then
    return
  end
  register_subcommand("textwidth", {
    handler = function(args)
      if #args == 0 then
        notify.error("[textwidth] Usage: textwidth <N|max>")
        return
      end
      local width
      if args[1] == "max" or args[1] == "MAX" then
        width = vim.api.nvim_win_get_width(0)
      else
        width = tonumber(args[1])
        if not width or width <= 0 then
          notify.error("[textwidth] Width must be a positive integer or 'max'")
          return
        end
      end
      vim.bo.textwidth = width
      tw.reflow_buffer(0, width)
      notify.info(string.format("Set textwidth=%d and reflowed buffer", width))
    end,
    complete = function()
      return { "max", "80", "120" }
    end,
    nargs = "1",
    desc = "Reflow text to width: textwidth <N|max>",
  })
end

local function setup_filter_lines()
  local ok, fl = pcall(require, "buffer_ctx.format.filter_lines")
  if not ok then
    return
  end
  register_subcommand("filter", {
    handler = function(args)
      if #args == 0 then
        notify.error("[filter] Usage: filter [--remove] <pattern> ...")
        return
      end
      local remove_flag, conditions = fl.parse_filter_args(args)
      if #conditions == 0 then
        notify.warn("[filter] No conditions provided")
        return
      end
      local bufnr = vim.api.nvim_get_current_buf()
      local before = vim.api.nvim_buf_line_count(bufnr)
      local success, err = fl.filter_lines(bufnr, conditions, remove_flag)
      if not success then
        notify.warn(string.format("[filter] %s", err or "Unknown error"))
        return
      end
      local after = #vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      notify.info(string.format("[filter] %d → %d lines", before, after))
    end,
    complete = function(arg_lead)
      if vim.startswith("--remove", arg_lead) then
        return { "--remove" }
      end
      if vim.startswith("-r", arg_lead) then
        return { "-r" }
      end
      return {}
    end,
    nargs = "+",
    desc = "Filter lines: filter [--remove] <pattern> ...",
  })
end

local function setup_misc()
  local ok, misc = pcall(require, "buffer_ctx.format.misc")
  if not ok then
    return
  end
  misc.register_subcommands(register_subcommand)
end

local function setup_blank_lines()
  local ok, bl = pcall(require, "buffer_ctx.format.blank_lines")
  if not ok then
    return
  end
  bl.register_subcommands(register_subcommand)
end

local function setup_enum_lines()
  local ok, core = pcall(require, "buffer_ctx.format.enum_lines")
  if not ok then
    return
  end

  local VALID_STYLES = { "decimal", "alpha", "ALPHA", "roman", "ROMAN" }
  local STYLE_SET = {}
  for _, s in ipairs(VALID_STYLES) do
    STYLE_SET[s] = true
  end

  ---@param args string[]
  ---@return table opts, string|nil err
  local function parse_enum_args(args)
    local opts = {}
    for _, raw in ipairs(args) do
      local key, val = raw:match("^([%w_]+)=(.+)$")
      if key and val then
        key = key:lower()
        if key == "style" then
          if not STYLE_SET[val] then
            return opts,
              string.format("Invalid style %q – valid: %s", val, table.concat(VALID_STYLES, ", "))
          end
          opts.style = val
        elseif key == "sep" then
          opts.sep = val
        elseif key == "start" then
          local n = tonumber(val)
          if not n or n < 1 then
            return opts, string.format("start= must be a positive integer, got %q", val)
          end
          opts.start = math.floor(n)
        elseif key == "inline" then
          if val == "true" then
            opts.inline = true
          elseif val == "false" then
            opts.inline = false
          else
            return opts, string.format("inline= must be true or false, got %q", val)
          end
        else
          return opts, string.format("Unknown option %q", raw)
        end
      elseif STYLE_SET[raw] then
        opts.style = raw
      else
        return opts,
          string.format(
            "Unknown argument %q – expected a style (%s) or key=value.",
            raw,
            table.concat(VALID_STYLES, "|")
          )
      end
    end
    return opts, nil
  end

  register_subcommand("enum", {
    handler = function(args)
      local opts, err = parse_enum_args(args)
      if err then
        notify.error(string.format("[enum] %s", err))
        return
      end
      core.enum_selection(opts)
    end,
    complete = function(arg_lead)
      local candidates = {
        "decimal",
        "alpha",
        "ALPHA",
        "roman",
        "ROMAN",
        "style=decimal",
        "style=alpha",
        "style=ALPHA",
        "style=roman",
        "style=ROMAN",
        "sep=.",
        "sep=)",
        "sep=:",
        "start=1",
        "inline=true",
        "inline=false",
      }
      local out = {}
      for _, c in ipairs(candidates) do
        if vim.startswith(c, arg_lead) then
          out[#out + 1] = c
        end
      end
      return out
    end,
    nargs = "*",
    range = true,
    desc = "Enumerate tokens in visual selection: enum [STYLE] [sep=SEP] [start=N] [inline=bool]",
  })
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public entry point
-- ─────────────────────────────────────────────────────────────────────────────

---@param cfg { enable?: boolean, command?: string }|nil
function M.setup(cfg)
  cfg = cfg or {}
  if cfg.enable == false then
    return
  end

  setup_column_align()
  setup_table()
  setup_text_width()
  setup_filter_lines()
  setup_misc()
  setup_enum_lines()
  setup_blank_lines()

  local cmd_name = cfg.command or "Format"
  vim.api.nvim_create_user_command(cmd_name, format_handler, {
    nargs = "*",
    range = true,
    complete = format_complete,
    desc = "[buffer_ctx.format] Unified formatting command with subcommands",
  })
end

return M
