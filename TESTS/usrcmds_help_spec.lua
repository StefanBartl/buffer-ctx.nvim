-- TESTS/usrcmds_help_spec.lua -- every flag and key=value pair of `:Insert` and `:Copy` has a line
-- in lib.nvim's option float (today that is `:Insert imagepaste ... path=`).
--
-- The text comes from the `desc` of each KvSpec in buffer_ctx.commands. A new option without one
-- shows up as a bare row in the cheatsheet, so this fails until it is described.

return function(H)
  local ok, composer = pcall(require, "lib.nvim.bindings.usercmd.composer")
  H.ok(ok, "the composer loads")

  -- A lib.nvim older than `help.undocumented` cannot answer the question; that is a missing
  -- feature of the dependency, not a defect of this plugin.
  if type(composer.help.undocumented) ~= "function" then
    return
  end

  -- Idempotent (re-registering replaces the verbs), so this holds whatever ran before.
  require("buffer_ctx.commands").register()

  for _, name in ipairs({ "Insert", "Copy" }) do
    H.ok(composer.registry()[name] ~= nil, ":" .. name .. " is registered through the composer")

    local missing = {}
    for _, m in ipairs(composer.help.undocumented(name)) do
      missing[#missing + 1] = ("%s %s"):format(m.route, m.name)
    end
    H.eq(
      #missing,
      0,
      ":" .. name .. " options without a help text: " .. table.concat(missing, ", ")
    )
  end
end
