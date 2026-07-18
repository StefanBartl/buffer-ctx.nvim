# Lua API

```lua
local ctx = require("buffer_ctx")

ctx.setup(opts)           -- configure + activate (idempotent)
ctx.insert(subcmd, args)  -- same as :Insert {subcmd} [args…]
ctx.copy(subcmd, args)    -- same as :Copy {subcmd} [args…]
```

See [Commands](commands.md) for the full list of `subcmd` values and their arguments.
