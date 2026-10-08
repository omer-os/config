-- Language servers for the web stack (Svelte, Tailwind, TypeScript).
--
-- These used to be set up with bare `require("lspconfig").<server>.setup({})`
-- calls at the bottom of init.lua. That ran outside LazyVim's LSP pipeline, so
-- the servers were configured twice (once here, once by LazyVim) and missed the
-- shared capabilities/keymaps. Declaring them as `opts.servers` hands them to
-- LazyVim, which registers them the 0.11+ way via `vim.lsp.config`.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- Inline type hints (`: string`, `: number`, ...) break up long lines and
      -- get in the way once wrap is on. Toggle back per buffer with <leader>uh.
      inlay_hints = { enabled = false },
      servers = {
        svelte = {},
        tailwindcss = {},
        ts_ls = {},
      },
    },
  },

  -- dressing.nvim used to come in as a flutter-tools dependency and took over
  -- vim.ui.select/vim.ui.input, which LazyVim routes through snacks.nvim.
  -- Keep it off so prompts stay consistent (and :checkhealth stays clean).
  { "stevearc/dressing.nvim", enabled = false },
}
