---@module 'buffer_ctx.ops.snippet'
---@brief VSCode-compatible snippet loading, as a lightweight alternative to a
--- full snippet engine.
---@description
--- Reads snippet files in the VSCode format:
---
---   { "Name": { "prefix": "x", "body": ["line", "line"], "description": "…" } }
---
--- A snippet is addressable by its key *or* its prefix. Tabstop placeholders
--- ($1, ${2:default}, $0) are not expanded — buffer-ctx inserts plain text, so
--- ${2:default} becomes "default" and bare tabstops are dropped. Anything
--- needing real tabstop navigation wants a snippet engine, not this.
---@see buffer_ctx.ops.boilerplate for the built-in, code-defined templates

local M = {}
local fn = vim.fn

---Snippet source files, newest configuration wins.
---@type string[]
local sources = {}

---@param paths string[]  file paths, may contain ~ or environment variables
---@return nil
function M.set_sources(paths)
  sources = {}
  for _, p in ipairs(paths or {}) do
    if type(p) == "string" and p ~= "" then
      sources[#sources + 1] = fn.expand(p)
    end
  end
end

---@return string[]
function M.get_sources()
  return vim.deepcopy(sources)
end

---Strip VSCode tabstops/placeholders down to plain text.
--- ${1:name} → name · ${1|a,b|} → a · $1 / $0 → removed
---@param line string
---@return string
local function strip_tabstops(line)
  -- Choice syntax first: its inner text contains commas that the placeholder
  -- pattern below would otherwise keep verbatim.
  line = line:gsub("%${%d+|([^,|]*)[^|]*|}", "%1")
  line = line:gsub("%${%d+:([^}]*)}", "%1")
  line = line:gsub("%${%d+}", "")
  line = line:gsub("%$%d+", "")
  return line
end

---Read and decode one snippet file.
---@param path string
---@return table|nil decoded, string|nil err
local function read_file(path)
  if fn.filereadable(path) ~= 1 then
    return nil, "snippet file not readable: " .. path
  end
  local content = table.concat(fn.readfile(path), "\n")
  if content == "" then
    return nil, "snippet file is empty: " .. path
  end
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    return nil, "invalid JSON in snippet file: " .. path
  end
  return decoded
end

---Collect every snippet from all configured sources.
---@return table<string, table> snippets keyed by name, string|nil err
function M.load()
  if #sources == 0 then
    return {}, "no snippet sources configured (set snippets = { paths = {…} })"
  end
  local all = {}
  local errors = {}
  for _, path in ipairs(sources) do
    local decoded, err = read_file(path)
    if decoded then
      for name, entry in pairs(decoded) do
        if type(entry) == "table" and entry.body then
          all[name] = entry
        end
      end
    else
      errors[#errors + 1] = err
    end
  end
  if vim.tbl_isempty(all) and #errors > 0 then
    return all, table.concat(errors, "; ")
  end
  return all
end

---List available snippet names (keys and prefixes both resolve in M.get)
---@return string[]
function M.list_keys()
  local snippets = M.load()
  local keys = {}
  for name, entry in pairs(snippets) do
    keys[#keys + 1] = name
    if type(entry.prefix) == "string" and entry.prefix ~= name then
      keys[#keys + 1] = entry.prefix
    end
  end
  table.sort(keys)
  return keys
end

---Resolve a snippet by name or prefix and return its body as plain lines.
---@param name string
---@return string[]|nil lines, string|nil err
function M.get(name)
  if not name or name == "" then
    return nil, "usage: snippet {name}"
  end

  local snippets, err = M.load()
  if vim.tbl_isempty(snippets) then
    return nil, err or "no snippets found"
  end

  local entry = snippets[name]
  if not entry then
    for _, candidate in pairs(snippets) do
      if candidate.prefix == name then
        entry = candidate
        break
      end
    end
  end
  if not entry then
    return nil, "unknown snippet: " .. name
  end

  -- VSCode allows body to be a single string or an array of lines.
  local body = entry.body
  if type(body) == "string" then
    body = vim.split(body, "\n", { plain = true })
  end
  if type(body) ~= "table" or #body == 0 then
    return nil, "snippet has an empty body: " .. name
  end

  local lines = {}
  for _, line in ipairs(body) do
    lines[#lines + 1] = strip_tabstops(tostring(line))
  end
  return lines
end

return M
