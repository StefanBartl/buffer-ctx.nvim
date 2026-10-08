-- TESTS/usrcmds_help_spec.lua -- every flag, key=value pair and positional argument of `:Insert`,
-- `:Copy`, `:Mark` and `:Format` has a line in lib.nvim's option float (the cheatsheet on the
-- command line; today `:Insert imagepaste ... path=` plus the first argument of every subcommand).
--
-- The text comes from the `desc` of each KvSpec / ArgSpec in buffer_ctx.commands, buffer_ctx.mark
-- and buffer_ctx.format, from the text of an argument's type (`register_type`) or, for a closed
-- value list, from `desc` / `enum_desc`. A new option without one shows up as a bare row in the
-- cheatsheet, so this fails until it is described.

return function(H)
  local ok, composer = pcall(require, "lib.nvim.bindings.usercmd.composer")
  H.ok(ok, "the composer loads")

  -- A lib.nvim older than `help.undocumented` cannot answer the question; that is a missing
  -- feature of the dependency, not a defect of this plugin.
  if type(composer.help.undocumented) ~= "function" then
    return
  end
  local entries = require("lib.nvim.bindings.usercmd.composer.help.entries")

  -- Idempotent (re-registering replaces the verbs), so this holds whatever ran before.
  require("buffer_ctx.commands").register()
  require("buffer_ctx.mark").setup({})
  require("buffer_ctx.format").setup({})

  -- The house style of the float: one short line, no trailing full stop.
  local function check_style(label, text)
    H.ok(type(text) == "string" and text ~= "", label .. " shows a text")
    H.ok(not text:find("\n", 1, true), label .. " is one line")
    H.ok(#text <= 80, label .. " stays short (" .. #text .. " chars)")
    H.ok(not text:find("%.$"), label .. " has no trailing full stop")
  end

  for _, name in ipairs({ "Insert", "Copy", "Mark", "Format" }) do
    H.ok(composer.registry()[name] ~= nil, ":" .. name .. " is registered through the composer")

    local missing = {}
    -- `args = true` also lists the positional arguments (an older lib.nvim ignores it).
    for _, m in ipairs(composer.help.undocumented(name, { args = true })) do
      missing[#missing + 1] = ("%s %s %s"):format(m.route, m.kind, m.name)
    end
    H.eq(
      #missing,
      0,
      ":" .. name .. " options and arguments without a help text: " .. table.concat(missing, ", ")
    )

    -- Every text that is there follows the style.
    local walked = 0
    for _, route in ipairs(composer.registry()[name]:spec().routes or {}) do
      local path = table.concat(route.path, " ")
      for _, arg in ipairs(route.args or {}) do
        local text = entries.arg_desc and entries.arg_desc(arg) or arg.desc
        if text then
          walked = walked + 1
          check_style(":" .. name .. " " .. path .. " " .. arg.name, text)
        end
        for value, vtext in pairs(arg.enum_desc or {}) do
          walked = walked + 1
          check_style(":" .. name .. " " .. path .. " " .. arg.name .. " = " .. value, vtext)
        end
      end
    end
    H.ok(walked > 0, ":" .. name .. " has argument texts that were actually walked")
  end

  -- A subcommand that takes no argument declares no slot (instead of one nobody can describe).
  for _, name in ipairs({ "linecount", "bufnr" }) do
    for _, verb in ipairs({ "Insert", "Copy" }) do
      for _, route in ipairs(composer.registry()[verb]:spec().routes or {}) do
        if route.path[1] == name then
          H.eq(#(route.args or {}), 0, ":" .. verb .. " " .. name .. " takes no argument")
        end
      end
    end
  end
end
