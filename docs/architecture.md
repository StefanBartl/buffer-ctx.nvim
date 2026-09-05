# Architecture

```
lua/buffer_ctx/
  init.lua                 setup() + public Lua facade (insert/copy wrappers)
  @types.lua               shared LuaLS type annotations
  health.lua               :checkhealth buffer_ctx (+ .format, .mark sub-reports)
  commands.lua             :Insert/:Copy dispatch table + the two filepath compat commands
  config/
    init.lua               runtime store (setup/get)
    DEFAULTS.lua           typed default configuration
  bindings/
    init.lua               orchestrator: core keymaps + :Insert/:Copy registration
    keymaps.lua            the 3 base keymaps (location/module/filepath copy)
    usrcmds.lua            registers :Insert and :Copy via lib.nvim's composer
    autocmds.lua           no autocmds defined here; stable extension point
                           (the actual one -- BufferCtxMarkCleanup -- lives in mark/init.lua)
  format/
    init.lua               :Format dispatcher + subcommand registration
    column_align.lua       :Format column <N> [fill]
    table_fmt.lua          :Format table [ALIGN] [opts] (GFM table formatter)
    text_width.lua         :Format textwidth <N|max>
    filter_lines.lua       :Format filter [--remove] <pattern>...
    enum_lines.lua         :Format enum [STYLE] [opts]
    blank_lines.lua        :Format squeeze (blank-line collapse, range-aware)
    misc.lua               :Format trim|sort|unique|case|indent|clear
    types/
      init.lua             type anchor for the format domain
  mark/
    init.lua               :Mark command tree (toggle/toggle_range/clear/yank);
                           registers the BufferCtxMarkCleanup autocmd (BufDelete/BufWipeout)
    types/
      init.lua             type anchor for the mark domain
  ops/
    filepath.lua           path string builder (relative/absolute/nvim/lua/unix/win/…)
    module.lua             Lua module path derivation + require()/@module/import formatting
    location.lua           "path:line" / "path:L1-L2"
    timestamp.lua          timestamp formatting (13 named styles + --utc)
    uuid.lua               UUIDv4 (soft dep: lib.nvim's lib.lua.uuid, else standalone)
    annotation.lua         LuaCATS annotation line generation (@class/@param/@field/…)
    boilerplate/
      init.lua             template registry; each key required lazily on first use
      templates/
        guard.lua          guard-clause template (interactive)
        html.lua           html-* templates (figure/code/quote/table/aside/pagination/…)
        lua.lua            lua-* templates (module/class/function/enum/test)
        markdown.lua       md-frontmatter template
        nvim.lua           nvim-autocmd / nvim-keymap templates
        utils.lua          shared template-building helpers
    snippet.lua            VSCode-format snippet loading (:Insert/:Copy snippet)
    env.lua                environment variable read + name listing (completion)
    git.lua                git revision info (hash/short/branch/tag), buffer-dir scoped
    bufinfo.lua            linecount / bufnr (plain buffer introspection)
    types/
      init.lua             type anchor for the ops domain (including ops/boilerplate)
  util/
    clip.lua               clipboard sink, unnamed-register fallback; status only, never notifies
    cursor.lua             cursor-relative buffer insertion (inline text or whole lines)
    map.lua                keymap wrapper; upgrades to lib.nvim's map helper when present
    notify.lua             "[buffer-ctx] "-prefixed vim.notify wrapper; lib.nvim soft dep
    path.lua               pure path helpers: module-path derivation, cwd-relative, depth-slicing
lua/telescope/_extensions/
  buffer_ctx.lua           :Telescope buffer_ctx boilerplate (optional, telescope.nvim installed)
plugin/
  buffer_ctx.lua           guard (vim.g.loaded_buffer_ctx)
doc/
  buffer-ctx.txt           :h buffer-ctx.nvim vim help file
docs/
  BINDINGS.md              machine-readable binding cheatsheet
TESTS/
  *_spec.lua               headless spec suite (see TESTS/README.md)
```
