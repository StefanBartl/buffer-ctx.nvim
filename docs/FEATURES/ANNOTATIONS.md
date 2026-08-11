# Annotations

LuaCATS/LuaLS annotation generation — the `---@...` comment lines that
give LuaLS types, without typing the boilerplate syntax by hand.

## LuaCATS annotation lines

Nine one-line annotation types: `module` (derived from the buffer's own
path, no prompt needed), `class`, `field`, `param`, `return`, `alias`,
`overload`, `diagnostic`, `deprecated`. Any argument not supplied on the
command line falls back to an interactive `vim.fn.input()` prompt, so the
subcommand is fully usable with zero arguments. `overload` and
`deprecated` reassemble multi-word input into one string instead of
taking only the first word, since a function signature or a deprecation
reason both routinely contain spaces.

- **Module:** `ops/annotation.lua` (`M.get`)
- **Usercmds:** `:Insert annotation {type} [args…]`, `:Copy annotation {type} [args…]`

```
:Insert annotation module                        → ---@module 'buffer_ctx.ops.module'
:Insert annotation overload fun(a: string): bool → ---@overload fun(a: string): bool
:Insert annotation deprecated use M.new instead  → ---@deprecated use M.new instead
```

`overload` wraps its argument in `fun(…)` automatically if the input
doesn't already start with it.

## Guided function-annotation dialog

`annotation function` is the one type that doesn't map to a single line:
it walks a short dialog (description, then repeated name/type prompts
per parameter until one is left empty, then a return type) and returns a
ready-made multi-line `---@param`/`---@return` block. `:Copy annotation
function` joins the generated lines with `\n` before writing to the
clipboard, so the result is one pasteable string rather than several
separate copy operations.

- **Module:** `ops/annotation.lua` (`M._interactive_function`)
- **Usercmds:** `:Insert annotation function`, `:Copy annotation function`
