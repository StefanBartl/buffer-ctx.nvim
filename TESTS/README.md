# Tests

Headless spec suite for buffer-ctx.nvim. The `ops/*` modules and
`util/path.lua` are pure(ish) functions — buffer-name-dependent — so they are
trivially testable without any UI interaction. `format/*` and `mark/*` operate
on scratch buffers created per-test.

## Run

From the repo root:

```sh
nvim --headless -u NONE -c "set rtp+=." -l TESTS/run.lua
```

The runner prints one line per spec and exits non-zero on the first failure
(`BUFFER_CTX_TESTS_OK` on success). `lib.nvim` is resolved from a sibling
checkout (`../lib.nvim`), `$LIB_NVIM_PATH`, or the lazy.nvim bootstrap copy.

## Layout

| File                    | Covers                                                                                                    |
| ------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `harness.lua`            | Shared assertions (`eq`, `ok`, `match`) and a `scratch(name, ft)` helper.                                  |
| `path_spec.lua`          | `util/path.lua`: module path derivation, sep normalization, depth, cwd-relative, nvim-config detection.    |
| `ops_spec.lua`           | `ops/module.lua`, `ops/uuid.lua`, `ops/timestamp.lua`, `ops/env.lua`, `ops/location.lua`, `ops/filepath.lua` happy paths. |
| `ops_edge_spec.lua`      | `ops/annotation.lua` (every type, incl. the `fn.input` fallbacks), `ops/git.lua` (every mode, real temp repos), and the unnamed-buffer / outside-`/lua/` / malformed-input error paths of `filepath`, `location`, `module` and `snippet`. |
| `format_spec.lua`        | `format/filter_lines.lua`, `format/enum_lines.lua`, `format/table_fmt.lua`, `format/column_align.lua`, `format/text_width.lua`, and `format/misc.lua` via `:Format` subcommands (happy paths). |
| `format_extra_spec.lua`  | `format/init.lua`'s `cfg.command`/`cfg.enable` gates and its subcommands' invalid-argument handling (driven through a real `:Format2` command); the rest of `format/misc.lua` (indent, case sentence/invalid, clear, sort/unique without every flag); and the error/edge branches of `column_align`, `text_width`, `enum_lines`, `filter_lines`, `blank_lines` and `table_fmt`. |
| `mark_spec.lua`          | `mark/init.lua`: toggle/yank flow, invalid-buffer guards, `BufDelete`/`BufWipeout` cleanup autocmd, ranges, categories. |
| `features_spec.lua`      | `git`, `bufinfo`, `snippet`, `location range`, the extra annotation types and boilerplate templates, sticky-UTC config, env completion. |
| `boilerplate_spec.lua`   | `ops/boilerplate/*`: every registered template renders, the has-id/no-id and default-fallback branches of each template module (`lua`, `html`, `nvim`, `markdown`, `utils`), the plain (non-interactive) half of `guard.lua`, and the registry's unknown-key error. |
| `bindings_spec.lua`      | `bindings/keymaps.lua` (attach with defaults/overrides/`false`, driving the bound action end to end via clipboard), `bindings/usrcmds.lua`, `bindings/autocmds.lua`, and `bindings/init.lua`'s `cfg.commands` gate (via stubbed sub-registrars). |
| `util_spec.lua`          | `util/clip.lua`'s pure-sink contract, `util/cursor.lua`'s mutation guards, and the lib.nvim-present/absent soft-dependency branches of `util/notify.lua` and `util/map.lua` (forced via `package.preload`). |
| `config_spec.lua`        | `config/init.lua`'s deep-merge `setup()`/`get()` and the non-table-argument guard, plus `health.lua`'s report with the default config and with `format`/`mark` disabled. Runs last (see below). |
| `run.lua`                | Runner: loads every `*_spec.lua`, reports results, sets exit code.                                        |

## Coverage

Every `lua/buffer_ctx/**/*.lua` file with real logic or branching has a
dedicated real-assertion suite (or a section of one), following top to
bottom the tour above: pure path/ops helpers, the annotation/git/snippet edge
cases (real temp git repos and directories, not mocked shell output), the
`:Format`/`:Mark`/`:Insert`/`:Copy` command layer end to end (including
invalid-argument branches, driven through the actual registered commands),
every boilerplate template, the keymap/usercmd/autocmd binding layer, the
soft-dependency (lib.nvim present/absent) fallback branches shared by
`util/notify.lua` and `util/map.lua`, config's deep-merge semantics, and
`:checkhealth buffer_ctx`'s enabled and disabled-subsystem report paths.

Two real bugs surfaced while writing this pass and are pinned as regression
tests (with a `BUG:`-prefixed assertion message) rather than worked around,
so a future fix shows up as an intentional, obvious test change:

- **`format/text_width.lua`'s bulleted-list reflow duplicates the bullet.**
  `detect_prefixes()` extracts a line's leading bullet/number marker (e.g.
  `"- "`) into `first_prefix` for `wrap_words()`, but `flush()` only strips
  leading *whitespace* from the source line before tokenising it — the
  bullet text itself is never removed, so it is re-emitted both as the
  prefix and as an ordinary token. Reflowing `"- one two three four five
  six"` at width 12 yields `"-  - one two"` instead of `"- one two"`.
- **`format/enum_lines.lua`'s `alpha`/`ALPHA` enum styles carry a spurious
  leading letter.** `alpha_marker()`'s digit-generation loop runs one
  iteration too many — its `until n < -1` exit check is off by one against
  the `n % 26` digit it just consumed — so every label gets an extra
  leading `z`/`Z`: enumerating three tokens with `style=alpha` produces
  `za.`, `zb.`, `zc.` instead of `a.`, `b.`, `c.`.

A third issue was found but isn't a test bug at all: **`util/map.lua`'s
lib.nvim detection is always false.** It gates on
`type(lib_map) == "function"`, but `require("lib.nvim.bindings.keymap")`
returns a *table* that is merely made callable via `__call` (documented in
that module's own header) — `type()` reports `"table"` regardless of
`__call`, so `buffer_ctx.util.map` never actually uses lib.nvim's keymap
helper, even when lib.nvim is installed and `util/notify.lua`'s equivalent
check (which compares against a table, correctly) is finding it. This one
has no user-visible effect (the plain `vim.keymap.set` fallback works
identically) beyond the health report's optional-dependency line always
saying "not found".

### Deliberately left untested

- **`plugin/buffer_ctx.lua`** — a 3-line `vim.g.loaded_buffer_ctx` guard with
  no branching of its own; `setup()`'s idempotency is exercised through
  `buffer_ctx` itself elsewhere.
- **`lua/telescope/_extensions/buffer_ctx.lua`** — a thin adapter to
  Telescope's picker API (`pickers.new`, `finders.new_table`, a buffer
  previewer). Its only real logic — `is_interactive()`'s placeholder branch
  and the filetype-from-key-prefix guess — wraps `ops/boilerplate.lua`
  functions that are already covered directly; the rest is Telescope
  plumbing with no independent behaviour to assert on, and telescope.nvim
  isn't a dependency available in this suite's runtimepath.
- **`lua/buffer_ctx/@types.lua`, `format/types/init.lua`,
  `mark/types/init.lua`, `ops/types/init.lua`** — `---@meta` type-anchor
  files that return an empty table; no runtime behavior to test.
- **`format/table_fmt.lua`'s `scope=cwd`** (recursive `*.md` glob + per-file
  progress reporting) — every other scope (`cursor`, `buffer`, an explicit
  unreadable path) and `table_fmt`'s own `parse_args` error branches are
  covered; `cwd` specifically would need to change Neovim's actual working
  directory mid-suite, which every other spec's cwd-relative buffer-naming
  assumption depends on staying put.

## Adding a spec

Create `<name>_spec.lua` returning `function(H) … end` (use `H.eq` / `H.ok` /
`H.match` / `H.scratch`) and add its filename to the `specs` list in
`run.lua`. `config_spec.lua` calls `buffer_ctx.config.setup()` directly and
restores the defaults at the end, so it must stay last in that list unless a
future spec is written to tolerate a non-default active config.
