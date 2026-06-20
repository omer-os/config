return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    ensure_installed = { "svelte", "typescript", "javascript", "html", "css" },
    highlight = {
      enable = true,
    },
  },
}
