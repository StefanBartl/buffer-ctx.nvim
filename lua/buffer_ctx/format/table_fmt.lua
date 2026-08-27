---@module 'buffer_ctx.format.table_fmt'
--- Markdown table formatter with per-role and per-column alignment control.
--- Public API:
---   M.format_table_at_cursor(bufnr, opts)   – format the table under the cursor
---   M.format_tables_in_buffer(bufnr, opts)  – format every table in a buffer
---   M.format_tables_in_scope(opts)          – scope: "cursor"|"buffer"|"cwd"|<path>
---   M.setup(register_fn, notify_mod)        – register the "table" :Format subcommand
---
--- The parse/render engine now lives in `lib.nvim.markdown.table` (it used to
--- be two byte-drifted copies, one here and one in markdown.nvim — see that
--- module's README for the extraction). This file keeps everything the lib
--- module deliberately doesn't do: notify wiring, per-file progress for the
--- "cwd" scope, *.md file collection, and subcommand registration.

local notify = require("buffer_ctx.util.notify")
local globbable = require("lib.nvim.fs.globbable")
local lib_table = require("lib.nvim.markdown.table")

local M = {}

-- Optional: per-file progress for the "cwd" scope, which formats every
-- *.md file under cwd and can take a while in a large tree. No-op (returns
-- nil) when lib.nvim isn't installed — formatting still runs, just silently.
local ok_progress, progress_mod = pcall(require, "lib.nvim.progress")
---@internal
---@return table|nil
local function new_progress()
  if not ok_progress then
    return nil
  end
  return progress_mod.create({ title = "[buffer_ctx.table_fmt]" })
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Module-level defaults
-- ─────────────────────────────────────────────────────────────────────────────

local _cfg = { header_align = "center", entry_align = "center" }

local VALID_ALIGN = { left = true, center = true, right = true }

---@internal
---@param warnings string[]
local function report_override_warnings(warnings)
  for _, w in ipairs(warnings) do
    notify.warn(w)
  end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- *.md file collection
-- ─────────────────────────────────────────────────────────────────────────────

---@internal
---@param dir string
---@return string[]
local function collect_md_files(dir)
  dir = dir:gsub("[/\\]$", "")
  -- Glob reads its argument as a pattern, so an 8.3 short root ("~1") is read
  -- as a home-directory reference and matches nothing. See lib.nvim.fs.globbable.
  dir = globbable(dir)
  local result = vim.fn.glob(dir .. "/**/*.md", false, true)
  for _, f in ipairs(vim.fn.glob(dir .. "/*.md", false, true)) do
    result[#result + 1] = f
  end
  return result
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

---Format the Markdown table under the cursor.
---@param bufnr integer|nil
---@param opts table|nil
---@return boolean, string|nil
function M.format_table_at_cursor(bufnr, opts)
  opts = opts or {}
  local ok, err, warnings = lib_table.format_at_cursor(bufnr, {
    header_align = opts.header_align or _cfg.header_align,
    entry_align = opts.entry_align or _cfg.entry_align,
    col_overrides = opts.col_overrides,
  })
  report_override_warnings(warnings)
  return ok, err
end

---Format every Markdown table in a buffer.
---@param bufnr integer|nil
---@param opts table|nil
---@return boolean, string|nil, integer
function M.format_tables_in_buffer(bufnr, opts)
  opts = opts or {}
  local ok, err, count, warnings = lib_table.format_buffer(bufnr, {
    header_align = opts.header_align or _cfg.header_align,
    entry_align = opts.entry_align or _cfg.entry_align,
    col_overrides = opts.col_overrides,
  })
  report_override_warnings(warnings)
  return ok, err, count
end

---Format tables in the given scope: "cursor" | "buffer" | "cwd" | a file path.
---@param opts table|nil
---@return boolean, string|nil
function M.format_tables_in_scope(opts)
  opts = opts or {}
  local scope = opts.scope or "cursor"
  -- Note: file-scope formatting ("cwd" / a path below) never applies
  -- opts.col_overrides — only the buffer-facing scopes do. That matches the
  -- pre-extraction behaviour (the old local format_file always resolved
  -- overrides against `nil`), kept as-is rather than silently widened here.
  local file_opts = {
    header_align = opts.header_align or _cfg.header_align,
    entry_align = opts.entry_align or _cfg.entry_align,
  }

  if scope == "cursor" then
    return M.format_table_at_cursor(nil, opts)
  elseif scope == "buffer" then
    local ok, err, count = M.format_tables_in_buffer(nil, opts)
    if ok then
      notify.info(string.format("Formatted %d table(s) in buffer", count))
    end
    return ok, err
  elseif scope == "cwd" then
    local cwd = vim.fn.getcwd()
    local files = collect_md_files(cwd)
    if #files == 0 then
      notify.info("No *.md files found under " .. cwd)
      return true, nil
    end
    local prog = new_progress()
    local errors, cnt = {}, 0
    for i, path in ipairs(files) do
      if prog then
        prog:update({ text = vim.fn.fnamemodify(path, ":t"), current = i, total = #files })
      end
      local ok, err, _, warnings = lib_table.format_file(path, file_opts)
      report_override_warnings(warnings)
      if ok then
        cnt = cnt + 1
      else
        errors[#errors + 1] = err
      end
    end
    if prog then
      prog:finish(string.format("Formatted %d/%d file(s)", cnt, #files))
    end
    if #errors > 0 then
      notify.warn(
        string.format(
          "Formatted %d/%d files; %d error(s):\n  %s",
          cnt,
          #files,
          #errors,
          table.concat(errors, "\n  ")
        )
      )
    else
      notify.info(string.format("Formatted tables in %d file(s)", cnt))
    end
    return #errors == 0, #errors > 0 and table.concat(errors, "; ") or nil
  else
    local path = vim.fn.expand(scope)
    if vim.fn.filereadable(path) == 0 then
      return false, string.format("File not readable: %q", path)
    end
    local ok, err, _, warnings = lib_table.format_file(path, file_opts)
    report_override_warnings(warnings)
    if ok then
      notify.info(string.format("Formatted tables in %q", path))
    end
    return ok, err
  end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Subcommand registration
-- ─────────────────────────────────────────────────────────────────────────────

---@param register_fn  fun(name: string, def: table): nil
---@param notify_mod   table
function M.setup(register_fn, notify_mod)
  local n = notify_mod or notify

  ---@param arg_lead string
  ---@return string[]
  local function table_complete(arg_lead)
    local candidates = {
      "left",
      "center",
      "right",
      "header=left",
      "header=center",
      "header=right",
      "cell=left",
      "cell=center",
      "cell=right",
      "skip=",
      "scope=cursor",
      "scope=buffer",
      "scope=cwd",
    }
    local out = {}
    for _, c in ipairs(candidates) do
      if vim.startswith(c, arg_lead) then
        out[#out + 1] = c
      end
    end
    return out
  end

  ---@param args string[]
  ---@return table opts, string|nil err
  local function parse_args(args)
    local opts, positional = {}, {}
    for _, raw in ipairs(args) do
      local key, val = raw:match("^([%w_]+)=(.+)$")
      if key and val then
        key = key:lower()
        if key == "header" then
          if not VALID_ALIGN[val] then
            return opts, string.format("Invalid alignment for header=: %q", val)
          end
          opts.header_align = val
        elseif key == "cell" or key == "entry" then
          if not VALID_ALIGN[val] then
            return opts, string.format("Invalid alignment for cell=: %q", val)
          end
          opts.entry_align = val
        elseif key == "skip" then
          opts.col_overrides = opts.col_overrides or {}
          for part in val:gmatch("[^,]+") do
            part = part:match("^%s*(.-)%s*$")
            opts.col_overrides[#opts.col_overrides + 1] =
              { col = tonumber(part) or part, align = "left" }
          end
        elseif key == "scope" then
          opts.scope = val
        else
          return opts, string.format("Unknown option: %q", raw)
        end
      elseif VALID_ALIGN[raw:lower()] then
        positional[#positional + 1] = raw:lower()
      else
        return opts, string.format("Unknown argument: %q", raw)
      end
    end
    if #positional >= 1 and not opts.header_align then
      opts.header_align = positional[1]
    end
    if #positional >= 2 and not opts.entry_align then
      opts.entry_align = positional[2]
    elseif #positional == 1 and not opts.entry_align then
      opts.entry_align = positional[1]
    end
    return opts, nil
  end

  register_fn("table", {
    handler = function(args)
      local opts, parse_err = parse_args(args)
      if parse_err then
        n.error(string.format("[table] %s", parse_err))
        return
      end
      local scope = opts.scope or "cursor"
      local success, err
      if scope == "cursor" then
        success, err = M.format_table_at_cursor(vim.api.nvim_get_current_buf(), opts)
      else
        success, err = M.format_tables_in_scope(opts)
      end
      if not success then
        n.warn(string.format("[table] %s", err or "Unknown error"))
        return
      end
      if scope == "cursor" then
        n.info("Table formatted")
      end
    end,
    complete = function(arg_lead)
      return table_complete(arg_lead)
    end,
    nargs = "*",
    desc = "Format Markdown table(s): table [ALIGN] [header=ALIGN] [cell=ALIGN] [skip=COL] [scope=cursor|buffer|cwd|PATH]",
  })
end

return M
