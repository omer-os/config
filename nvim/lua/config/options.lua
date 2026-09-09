-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.backupcopy = "yes"

-- Put Mason's bin dir on PATH before anything else loads.
-- Mason only prepends it once mason.nvim itself is loaded, which is lazy, so
-- tools that get looked up earlier -- notably the tree-sitter CLI that
-- nvim-treesitter needs to build new parsers -- were reported as missing.
local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
if vim.fn.isdirectory(mason_bin) == 1 and not vim.env.PATH:find(mason_bin, 1, true) then
  vim.env.PATH = mason_bin .. ":" .. vim.env.PATH
end
