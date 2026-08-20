-- Dart-specific editor behaviour: formatting, indentation, and small QoL bits.

return {
  -- Format Dart through dartls (`dart format`). LazyVim's conform setup falls
  -- back to the LSP formatter when no dedicated formatter is registered, so all
  -- this needs to do is make sure Dart is not excluded.
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        dart = {}, -- empty list => LSP fallback (dart format)
      },
    },
  },

  -- Dart style is 2-space indent; also keeps the 80-col guide dartls formats to.
  {
    "LazyVim/LazyVim",
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("dart_indent", { clear = true }),
        pattern = { "dart" },
        callback = function()
          vim.opt_local.shiftwidth = 2
          vim.opt_local.tabstop = 2
          vim.opt_local.expandtab = true
          vim.opt_local.colorcolumn = "80"
        end,
      })
    end,
  },
}
