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
--- Built via lib.nvim.usercmd.composer: subcommand setup (register_subcommand,
--- the per-subcommand handler/complete/desc defs below and in the sibling
--- table_fmt/misc/blank_lines modules) is unchanged, only the final
--- registration step routes through composer instead of a hand-rolled
--- complete()/handler() pair.
---@see buffer_ctx.commands for the sibling :Insert / :Copy dispatch
---@see buffer_ctx.format.types for the subcommand type anchors

local composer = require("lib.nvim.usercmd.composer")

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

---Build one composer route per registered subcommand. A single optional
--- first-arg (`a1`) is declared, using a type whose completer delegates to
--- the subcommand's own `def.complete(arg_lead)` — every existing completer
--- here is already position-agnostic (offers the same candidates regardless
--- of how many tokens precede arg_lead), so this recovers real completion at
--- the first slot; further tokens fall through to `ctx.rest` uncompleted,
--- same tradeoff already accepted for :Insert/:Copy in buffer_ctx.commands.
--- `def.handler(args, ctx)` itself is called completely unchanged.
---@return table[]
local function build_routes()
  local routes = {}
  for name, def in pairs(subcommands) do
    composer.register_type("BUFFER_CTX_FORMAT_" .. name:upper(), {
      validate = function(raw) return true, raw, nil end,
      complete = function(arg_lead)
        local ok, result = pcall(def.complete, arg_lead)
        return (ok and result) or {}
      end,
    })
    routes[#routes + 1] = {
      path = { name },
      args = {
        { name = "a1", type = "BUFFER_CTX_FORMAT_" .. name:upper(), optional = true },
      },
      range = true,
      desc = def.desc,
      run = function(ctx)
        local args = {}
        if ctx.args.a1 ~= nil then
          args[1] = ctx.args.a1
        end
        for _, t in ipairs(ctx.rest) do
          args[#args + 1] = t
        end
        -- ctx.range.range is 0 when no range prefix was given; only then are
        -- line1/line2 meaningless (both default to the cursor line).
        local range_ctx = (ctx.range.range and ctx.range.range > 0)
          and { line1 = ctx.range.line1, line2 = ctx.range.line2 } or nil
        local ok, err = pcall(def.handler, args, range_ctx)
        if not ok then
          notify.error(string.format("[%s] %s", name, tostring(err)))
        end
      end,
    }
  end
  return routes
end

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

  composer.verb(cfg.command or "Format", {
    desc = "Unified formatting command with subcommands",
    routes = build_routes(),
  })
end

return M
