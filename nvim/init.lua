-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
local lspconfig = require("lspconfig")

lspconfig.svelte.setup({})
lspconfig.tailwindcss.setup({})
lspconfig.ts_ls.setup({})
