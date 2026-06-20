-- Make snacks.picker (Find Files, Grep, Explorer) skip junk dirs and
-- respect gitignore. The explorer shows gitignored files (e.g. .env) while
-- search sources do not. The `exclude` list always hides these dirs.
return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    local exclude = {
      ".git",
      "node_modules",
      "dist",
      "build",
      ".next",
      ".nuxt",
      ".svelte-kit",
      "target",
      ".venv",
      "__pycache__",
      ".cache",
    }

    opts.picker = opts.picker or {}
    opts.picker.sources = opts.picker.sources or {}

    for _, source in ipairs({ "files", "grep" }) do
      opts.picker.sources[source] = vim.tbl_deep_extend("force", opts.picker.sources[source] or {}, {
        hidden = true,
        ignored = false,
        exclude = exclude,
      })
    end

    opts.picker.sources.explorer = vim.tbl_deep_extend("force", opts.picker.sources.explorer or {}, {
      hidden = true,
      ignored = true,
      exclude = exclude,
    })

    return opts
  end,
}
