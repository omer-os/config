-- Flutter / Dart development setup
--
-- dartls comes from the Flutter SDK itself (no Mason install needed).
-- flutter-tools.nvim wires up the LSP, the device/emulator pickers, hot reload,
-- the dev log, DevTools and the DAP debug adapter.

return {
  -- Treesitter parsers for Dart + pubspec.yaml
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "dart", "yaml" } },
  },

  -- nvim-dap is required for the debugger; the dap.core extra brings dap-ui too.
  { "mfussenegger/nvim-dap", optional = true },

  {
    "akinsho/flutter-tools.nvim",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "stevearc/dressing.nvim", -- nicer device/emulator selection prompts
    },
    opts = {
      ui = {
        border = "rounded",
        notification_style = "native",
      },

      decorations = {
        statusline = {
          app_version = false,
          device = true,
        },
      },

      -- Hot reload/restart etc. work without this, but this gives you real
      -- breakpoints via nvim-dap.
      debugger = {
        enabled = true,
        run_via_dap = true,
        exception_breakpoints = {},
        evaluate_to_string_in_debug_views = true,
        register_configurations = function(_)
          local dap = require("dap")
          dap.configurations.dart = {
            {
              type = "dart",
              request = "launch",
              name = "Launch Flutter (debug)",
              dartSdkPath = "dart",
              flutterSdkPath = "flutter",
              program = "${workspaceFolder}/lib/main.dart",
              cwd = "${workspaceFolder}",
            },
            {
              type = "dart",
              request = "launch",
              name = "Launch Flutter (profile)",
              flutterMode = "profile",
              program = "${workspaceFolder}/lib/main.dart",
              cwd = "${workspaceFolder}",
            },
          }
          -- Pick up .vscode/launch.json if the project ships one
          pcall(function()
            require("dap.ext.vscode").load_launchjs(nil, { dart = { "dart" } })
          end)
        end,
      },

      root_patterns = { ".git", "pubspec.yaml" },

      -- Set to true if you manage Flutter versions with FVM
      fvm = false,

      -- The indent guides that connect nested widgets
      widget_guides = { enabled = true },

      -- Virtual `// Scaffold` hints at closing brackets of widget trees
      closing_tags = {
        highlight = "Comment",
        prefix = "// ",
        priority = 10,
        enabled = true,
      },

      dev_log = {
        enabled = true,
        notify_errors = false,
        open_cmd = "botright 15split",
      },

      dev_tools = {
        autostart = false,
        auto_open_browser = false,
      },

      outline = {
        open_cmd = "botright 40vnew",
        auto_open = false,
      },

      lsp = {
        -- Color swatches are handled by Neovim's built-in vim.lsp.document_color
        -- (see the LspAttach autocmd below); flutter-tools' own implementation is
        -- deprecated on 0.12+.
        color = { enabled = false },

        -- Merge blink.cmp's completion capabilities into dartls
        capabilities = function(default)
          local ok, blink = pcall(require, "blink.cmp")
          if ok then
            return blink.get_lsp_capabilities(default)
          end
          return default
        end,

        settings = {
          showTodos = true,
          completeFunctionCalls = true,
          enableSnippets = true,
          renameFilesWithClasses = "prompt",
          updateImportsOnRename = true,
          lineLength = 80,
          analysisExcludedFolders = {
            vim.fn.expand("$HOME/flutter/packages"),
            vim.fn.expand("$HOME/flutter/.pub-cache"),
            vim.fn.expand("$HOME/.pub-cache"),
          },
        },
      },
    },
    config = function(_, opts)
      require("flutter-tools").setup(opts)

      -- Native document colors (Neovim 0.12+): shows a ■ swatch next to
      -- Color(0xFF...) literals via dartls' textDocument/documentColor.
      if vim.lsp.document_color then
        vim.api.nvim_create_autocmd("LspAttach", {
          group = vim.api.nvim_create_augroup("flutter_document_color", { clear = true }),
          callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if client and client:supports_method("textDocument/documentColor") then
              vim.lsp.document_color.enable(true, args.buf, { style = "virtual" })
            end
          end,
        })
      end

      -- Hot reload on save, but only while an app is actually running
      -- (flutter-tools names its log buffer __FLUTTER_DEV_LOG__).
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = vim.api.nvim_create_augroup("flutter_hot_reload", { clear = true }),
        pattern = "*.dart",
        callback = function()
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_get_name(buf):match("__FLUTTER_DEV_LOG__") then
              vim.cmd("silent! FlutterReload")
              return
            end
          end
        end,
      })
    end,
    keys = {
      { "<leader>F", "", desc = "+flutter" },
      { "<leader>Fr", "<cmd>FlutterRun<cr>", desc = "Run" },
      { "<leader>Fh", "<cmd>FlutterReload<cr>", desc = "Hot reload" },
      { "<leader>FR", "<cmd>FlutterRestart<cr>", desc = "Hot restart" },
      { "<leader>Fq", "<cmd>FlutterQuit<cr>", desc = "Quit running app" },
      { "<leader>Fd", "<cmd>FlutterDevices<cr>", desc = "Devices" },
      { "<leader>Fe", "<cmd>FlutterEmulators<cr>", desc = "Emulators" },
      { "<leader>Fl", "<cmd>FlutterLogToggle<cr>", desc = "Toggle dev log" },
      { "<leader>FL", "<cmd>FlutterLogClear<cr>", desc = "Clear dev log" },
      { "<leader>Fo", "<cmd>FlutterOutlineToggle<cr>", desc = "Widget outline" },
      { "<leader>Ft", "<cmd>FlutterDevTools<cr>", desc = "Start DevTools" },
      { "<leader>FT", "<cmd>FlutterCopyProfilerUrl<cr>", desc = "Copy profiler URL" },
      { "<leader>Fg", "<cmd>FlutterPubGet<cr>", desc = "pub get" },
      { "<leader>Fu", "<cmd>FlutterPubUpgrade<cr>", desc = "pub upgrade" },
      { "<leader>Fs", "<cmd>FlutterSuper<cr>", desc = "Go to super class/method" },
      { "<leader>Fv", "<cmd>FlutterVisualDebug<cr>", desc = "Toggle visual debug" },
      { "<leader>FD", "<cmd>FlutterDetach<cr>", desc = "Detach from app" },
    },
  },

  -- <leader>Fa to search pub.dev and add a dependency to pubspec.yaml
  {
    "akinsho/pubspec-assist.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "BufRead pubspec.yaml",
    opts = {},
    keys = {
      { "<leader>Fa", "<cmd>PubspecAssistAddPackage<cr>", desc = "Add pub package" },
    },
  },
}
