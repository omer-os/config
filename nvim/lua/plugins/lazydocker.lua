-- lazydocker in a floating terminal (uses snacks.nvim, already bundled with LazyVim)
-- <leader>gd toggles it, mirroring <leader>gg for lazygit.
return {
  "folke/snacks.nvim",
  keys = {
    {
      "<leader>gd",
      function()
        Snacks.terminal.toggle("lazydocker", {
          win = {
            position = "float",
            width = 0.92,
            height = 0.92,
            border = "rounded",
            title = " lazydocker ",
            title_pos = "center",
          },
        })
      end,
      desc = "LazyDocker",
    },
  },
}
