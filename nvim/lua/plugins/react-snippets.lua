return {
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        providers = {
          snippets = {
            opts = {
              -- load snippets/react.json in jsx/tsx buffers
              extended_filetypes = {
                typescriptreact = { "react" },
                javascriptreact = { "react" },
              },
            },
          },
        },
      },
    },
  },
}
