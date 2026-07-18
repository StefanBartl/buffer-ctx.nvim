---@module 'telescope._extensions.buffer_ctx'
---@brief Optional Telescope extension: pick a boilerplate template with a live
--- preview of the lines it would generate.
---@description
--- Register with:  require("telescope").load_extension("buffer_ctx")
--- Then:           :Telescope buffer_ctx boilerplate
---
--- Telescope is an optional dependency — this file only ever loads when
--- Telescope itself requires it, so the plugin stays standalone.
---@see buffer_ctx.ops.boilerplate for the registry backing the picker

local ok_telescope, telescope = pcall(require, "telescope")
if not ok_telescope then
  error("telescope.nvim is required for the buffer_ctx extension")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

local boiler = require("buffer_ctx.ops.boilerplate")

---Render a template's lines for the preview pane.
---@param entry table
---@param bufnr integer
local function preview_template(entry, bufnr)
  local lines, err = boiler.get(entry.value, nil)
  if not lines then
    lines = { "-- preview unavailable: " .. (err or "unknown error") }
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  -- Best-effort syntax highlighting from the template's key prefix.
  local ft = entry.value:match("^(%a+)%-") or ""
  local FILETYPE = { lua = "lua", nvim = "lua", html = "html", md = "markdown", guard = "lua" }
  vim.bo[bufnr].filetype = FILETYPE[ft] or ""
end

---@param opts? table  standard Telescope picker options
local function boilerplate_picker(opts)
  opts = opts or {}
  local descs = boiler.describe()

  pickers
    .new(opts, {
      prompt_title = "buffer-ctx boilerplate",
      finder = finders.new_table({
        results = boiler.list_keys(),
        entry_maker = function(key)
          local desc = descs[key] or ""
          return {
            value = key,
            ordinal = key .. " " .. desc,
            display = string.format("%-22s %s", key, desc),
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = previewers.new_buffer_previewer({
        title = "Generated lines",
        define_preview = function(self, entry)
          preview_template(entry, self.state.bufnr)
        end,
      }),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not entry then
            return
          end
          local lines, err = boiler.get(entry.value, nil)
          if not lines then
            require("buffer_ctx.util.notify").error(err or "boilerplate failed")
            return
          end
          require("buffer_ctx.util.cursor").insert_lines(lines)
        end)
        return true
      end,
    })
    :find()
end

return telescope.register_extension({
  exports = {
    boilerplate = boilerplate_picker,
    -- Bare `:Telescope buffer_ctx` defaults to the boilerplate picker.
    buffer_ctx = boilerplate_picker,
  },
})
