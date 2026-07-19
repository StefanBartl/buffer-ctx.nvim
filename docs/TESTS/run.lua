-- docs/TESTS/run.lua — headless test runner for buffer-ctx.nvim.
--
-- Run from the repo root:
--   nvim --headless -u NONE -c "set rtp+=." -c "luafile docs/TESTS/run.lua" -c "qa!"
-- or:
--   nvim --headless -u NONE -c "set rtp+=." -l docs/TESTS/run.lua
--
-- Loads every *_spec.lua in this directory, runs it against the shared
-- harness, prints a per-spec result and exits non-zero on the first failing
-- spec (so it is CI-friendly).

local dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local H = dofile(dir .. "harness.lua")

-- buffer-ctx.nvim depends on lib.nvim at runtime: util/{path,clip,notify}.lua
-- use it as a soft/cosmetic dependency, but commands.lua/format/mark now
-- `require("lib.nvim.usercmd.composer")` unconditionally at module load (the
-- composer migration), so it's a HARD dependency for format_spec.lua and
-- mark_spec.lua specifically, which call buffer_ctx.setup(). The suite needs
-- it on the runtimepath. A sibling checkout wins over the plugin-manager
-- copy: the bootstrap clone under stdpath("data")/lazy is frequently stale.
local function add_lib_nvim()
  local candidates = {}
  if vim.env.LIB_NVIM_PATH then
    candidates[#candidates + 1] = vim.env.LIB_NVIM_PATH
  end
  candidates[#candidates + 1] = vim.fn.getcwd() .. "/../lib.nvim"
  candidates[#candidates + 1] = vim.fn.stdpath("data") .. "/lazy/lib.nvim"

  for _, path in ipairs(candidates) do
    local norm = vim.fs.normalize(path)
    if vim.fn.isdirectory(norm .. "/lua/lib") == 1 then
      vim.opt.rtp:append(norm)
      package.path = table.concat({
        norm .. "/lua/?.lua",
        norm .. "/lua/?/init.lua",
        package.path,
      }, ";")
      return norm
    end
  end
  return nil
end

-- util/{notify,map,path,clip}.lua fall back to native equivalents when
-- lib.nvim is absent, but format_spec.lua/mark_spec.lua call buffer_ctx.setup()
-- which now hard-requires lib.nvim.usercmd.composer (no pcall, matching every
-- other composer-migrated plugin) — so those two specs WILL fail without it.
if not add_lib_nvim() then
  print("note  lib.nvim not found — format_spec.lua/mark_spec.lua will fail.")
  print("      Set $LIB_NVIM_PATH or check it out next to this repo.")
end

-- Ordered so failures point at the smallest layer first.
local specs = {
  "path_spec.lua",
  "ops_spec.lua",
  "format_spec.lua",
  "mark_spec.lua",
  "features_spec.lua",
}

local failed = 0
for _, name in ipairs(specs) do
  local run = dofile(dir .. name)
  local ok, err = pcall(run, H)
  if ok then
    print(("ok    %s"):format(name))
  else
    failed = failed + 1
    print(("FAIL  %s\n      %s"):format(name, tostring(err)))
  end
end

if failed > 0 then
  print(("\n%d spec(s) failed"):format(failed))
  os.exit(1)
end

print("\nBUFFER_CTX_TESTS_OK")
