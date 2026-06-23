---@module 'buffer_ctx.ops.boilerplate.templates.html'
local M = {}

function M.figure(id)
  id = id or "TODO"
  return {
    string.format('<figure style="text-align:center;" id="#fig-tbl-%s">', id),
    '  <img src="" alt="">',
    "  <figcaption></figcaption>",
    "</figure>",
  }
end

function M.code(id)
  id = id or "TODO"
  return {
    string.format('<figure id="#code-%s">', id),
    '  <pre><code class="">',
    "",
    "  </code></pre>",
    "  <figcaption><strong>Listing:</strong> </figcaption>",
    "</figure>",
  }
end

function M.quote(id)
  id = id or "TODO"
  return {
    string.format('<figure id="#quote-%s">', id),
    '  <blockquote style="border-left: 4px solid #ddd; padding-left: 1em; margin: 1em 0; font-style: italic;">',
    "    ",
    "  </blockquote>",
    '  <figcaption style="text-align: right;">— </figcaption>',
    "</figure>",
  }
end

function M.formula_table(id)
  id = id or "TODO"
  return {
    string.format('<figure id="#tbl-formula-%s">', id),
    '  <table style="border-collapse: collapse; width: 100%;">',
    "    <caption><strong>Formeln:</strong> </caption>",
    "    <thead>",
    "      <tr>",
    '        <th style="border: 1px solid #ddd; padding: 8px;">Name</th>',
    '        <th style="border: 1px solid #ddd; padding: 8px;">Formula</th>',
    '        <th style="border: 1px solid #ddd; padding: 8px;">Variables</th>',
    "      </tr>",
    "    </thead>",
    "    <tbody>",
    "      <tr>",
    '        <td style="border: 1px solid #ddd; padding: 8px;"></td>',
    '        <td style="border: 1px solid #ddd; padding: 8px;">$  $</td>',
    '        <td style="border: 1px solid #ddd; padding: 8px;"></td>',
    "      </tr>",
    "    </tbody>",
    "  </table>",
    "</figure>",
  }
end

function M.aside(id)
  id = id or "TODO"
  return {
    string.format('<aside id="#aside-%s" style="border-left: 3px solid #ddd; padding-left: 1em; margin: 1em 0;">', id),
    "  <strong>Note:</strong> ",
    "</aside>",
  }
end

function M.pagination(id)
  id = id or "TODO"
  return {
    string.format('<nav id="#pagination-%s" style="text-align: center; margin: 2em 0;">', id),
    '  <a href="#" style="padding: 0.5em 1em; margin: 0 0.2em; border: 1px solid #ddd; text-decoration: none;">← Previous</a>',
    '  <a href="#" style="padding: 0.5em 1em; margin: 0 0.2em; border: 1px solid #ddd; text-decoration: none;">Next →</a>',
    "</nav>",
  }
end

function M.accordion(id)
  id = id or "TODO"
  return {
    string.format('<details id="#accordion-%s" style="border: 1px solid #ddd; border-radius: 4px; padding: 0.5em 1em; margin: 0.5em 0;">', id),
    '  <summary style="cursor: pointer; font-weight: bold; user-select: none;">',
    "    ",
    "  </summary>",
    '  <div style="margin-top: 1em;">',
    "    ",
    "  </div>",
    "</details>",
  }
end

return M
