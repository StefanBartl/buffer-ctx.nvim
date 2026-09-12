# Around it

How buffer-ctx.nvim's scope differs from its siblings in the collection.

**[gopath.nvim](https://github.com/StefanBartl/gopath.nvim)** — the return
journey. buffer-ctx produces a `require("foo.bar")` or `path:line` reference;
gopath takes one written anywhere and jumps to what it names.

**[fileops.nvim](https://github.com/StefanBartl/fileops.nvim)** — acts on the
file rather than reading from it: create, rename, move, delete. buffer-ctx
tells you what the buffer *is*, fileops changes it.

[lib.nvim](https://github.com/StefanBartl/lib.nvim) is the one real
dependency — see [Installation](installation.md#requirements).
