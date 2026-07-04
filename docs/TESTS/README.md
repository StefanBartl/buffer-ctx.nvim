# Tests

Headless spec suite for buffer-ctx.nvim. The `ops/*` modules and
`util/path.lua` are pure(ish) functions — buffer-name-dependent — so they are
trivially testable without any UI interaction. `format/*` and `mark/*` operate
on scratch buffers created per-test.

## Run

From the repo root:

```sh
nvim --headless -u NONE -c "set rtp+=." -c "luafile docs/TESTS/run.lua" -c "qa!"
```

The runner prints one line per spec and exits non-zero on the first failure
(`BUFFER_CTX_TESTS_OK` on success).

## Layout

| File              | Covers                                                                 |
| ----------------- | ----------------------------------------------------------------------- |
| `harness.lua`     | Shared assertions (`eq`, `ok`, `match`) and a `scratch(name, ft)` helper. |
| `path_spec.lua`   | `util/path.lua`: module path derivation, sep normalization, depth, cwd-relative, nvim-config detection. |
| `ops_spec.lua`    | `ops/module.lua`, `ops/uuid.lua`, `ops/timestamp.lua`, `ops/env.lua`, `ops/location.lua`, `ops/filepath.lua`. |
| `format_spec.lua` | `format/filter_lines.lua`, `format/enum_lines.lua`, `format/table_fmt.lua`, `format/column_align.lua`, `format/text_width.lua`, and `format/misc.lua` via `:Format` subcommands. |
| `mark_spec.lua`   | `mark/init.lua`: toggle/yank flow, invalid-buffer guards, `BufDelete`/`BufWipeout` cleanup autocmd. |
| `run.lua`         | Runner: loads every `*_spec.lua`, reports results, sets exit code.       |

## Adding a spec

Create `<name>_spec.lua` returning `function(H) … end` (use `H.eq` / `H.ok` /
`H.match` / `H.scratch`) and add its filename to the `specs` list in
`run.lua`.
