-- Extra treesitter parsers.
-- NOTE: this used to live in lua/config/keymaps.lua, which LazyVim loads as a
-- config module rather than a plugin spec, so it was silently doing nothing.
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = { "svelte", "typescript", "javascript", "html", "css" },
  },
}
