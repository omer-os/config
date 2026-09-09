-- "Matrix" — neon-green-on-black theme matching the rest of the desktop.
--
-- Built on tokyonight (already a LazyVim dependency) rather than a new plugin,
-- so every highlight group tokyonight covers stays covered. The palette is
-- lifted from waybar/style.css + hyprland.lua so nvim, the bar and the window
-- borders all use the same greens: #00ff5f neon, #9dff2e lime, #35c95a mid,
-- #1c6b33 dim, #050a05 background.
--
-- Greens carry the whole syntax hierarchy by brightness (neon keywords -> lime
-- functions -> mid strings -> teal types), with amber and red reserved for
-- numbers/constants and errors so they still pop against all the green.
--
-- `transparent` is on to blend with kitty's background_opacity 0.82. Set it to
-- false below for a solid black background instead.
return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "night",
      transparent = true,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = false, bold = true },
        functions = {},
        variables = {},
        sidebars = "transparent",
        floats = "transparent",
      },

      on_colors = function(c)
        -- backgrounds / chrome
        c.bg = "#050a05"
        c.bg_dark = "#020502"
        c.bg_dark1 = "#020502"
        c.bg_float = "#070e07"
        c.bg_popup = "#070e07"
        c.bg_sidebar = "#040804"
        c.bg_statusline = "#040804"
        c.bg_highlight = "#0e1a10"
        c.bg_visual = "#15401f"
        c.bg_search = "#1c6b33"
        c.border = "#1c6b33"
        c.border_highlight = "#00ff5f"

        -- foregrounds
        c.fg = "#c2f7d2"
        c.fg_dark = "#8fd6a4"
        c.fg_float = "#c2f7d2"
        c.fg_sidebar = "#8fd6a4"
        c.fg_gutter = "#1a2e1f"
        c.comment = "#4a7d59"
        c.dark3 = "#2a4a33"
        c.dark5 = "#3a6244"
        c.terminal_black = "#123018"

        -- syntax: brightness carries the hierarchy
        c.magenta = "#00ff5f" -- keywords
        c.purple = "#00ff5f" -- control flow
        c.blue = "#9dff2e" -- functions
        c.green = "#35c95a" -- strings
        c.teal = "#5ef2c4" -- types
        c.cyan = "#5ef2c4"
        c.blue1 = "#5ef2c4"
        c.blue2 = "#2ee6a8"
        c.blue5 = "#7fe6a0" -- punctuation / delimiters
        c.blue6 = "#b8f5c8"
        c.blue7 = "#16351f"
        c.blue0 = "#1c6b33"
        c.green1 = "#2ee6a8"
        c.green2 = "#1c6b33"

        -- reserved contrast colors
        c.orange = "#ffb454" -- numbers, constants
        c.yellow = "#d4ff4d"
        c.red = "#ff5555"
        c.red1 = "#ff5555"
        c.magenta2 = "#ff3355"

        -- diagnostics
        c.error = "#ff5555"
        c.warning = "#ffb454"
        c.info = "#5ef2c4"
        c.hint = "#00ff5f"
        c.todo = "#9dff2e"

        c.git = { add = "#00ff5f", change = "#ffb454", delete = "#ff5555", ignore = "#3a6244" }
        c.gitSigns = { add = "#00ff5f", change = "#ffb454", delete = "#ff5555" }
      end,

      on_highlights = function(hl, c)
        -- cursor + current line: a green scanline
        hl.CursorLine = { bg = "#0c1a0f" }
        hl.CursorLineNr = { fg = "#00ff5f", bold = true }
        hl.LineNr = { fg = "#254a2f" }
        hl.Cursor = { fg = c.bg, bg = "#00ff5f" }
        hl.MatchParen = { fg = "#050a05", bg = "#9dff2e", bold = true }
        hl.Visual = { bg = "#15401f" }
        hl.ColorColumn = { bg = "#0a140c" }
        hl.WinSeparator = { fg = "#1c6b33" }
        hl.VertSplit = { fg = "#1c6b33" }

        -- floats / borders glow green
        hl.FloatBorder = { fg = "#1f8a44", bg = "NONE" }
        hl.NormalFloat = { fg = c.fg, bg = "NONE" }
        hl.Pmenu = { fg = c.fg, bg = "#070e07" }
        hl.PmenuSel = { fg = "#050a05", bg = "#00ff5f", bold = true }
        hl.PmenuSbar = { bg = "#0e1a10" }
        hl.PmenuThumb = { bg = "#1f8a44" }

        -- search
        hl.Search = { fg = "#050a05", bg = "#35c95a", bold = true }
        hl.IncSearch = { fg = "#050a05", bg = "#9dff2e", bold = true }
        hl.CurSearch = { fg = "#050a05", bg = "#00ff5f", bold = true }

        -- treesitter fine-tuning
        hl["@keyword"] = { fg = "#00ff5f", bold = true }
        hl["@keyword.function"] = { fg = "#00ff5f", bold = true }
        hl["@keyword.return"] = { fg = "#4dffb8", bold = true }
        hl["@function"] = { fg = "#9dff2e" }
        hl["@function.call"] = { fg = "#9dff2e" }
        hl["@function.builtin"] = { fg = "#9dff2e", italic = true }
        hl["@string"] = { fg = "#35c95a" }
        hl["@number"] = { fg = "#ffb454" }
        hl["@boolean"] = { fg = "#ffb454", bold = true }
        hl["@constant"] = { fg = "#ffb454" }
        hl["@type"] = { fg = "#5ef2c4" }
        hl["@type.builtin"] = { fg = "#5ef2c4", italic = true }
        hl["@variable"] = { fg = "#c2f7d2" }
        hl["@variable.member"] = { fg = "#8fd6a4" }
        hl["@property"] = { fg = "#8fd6a4" }
        hl["@punctuation.bracket"] = { fg = "#4a7d59" }
        hl["@punctuation.delimiter"] = { fg = "#4a7d59" }
        hl["@comment"] = { fg = "#4a7d59", italic = true }
        hl["@tag"] = { fg = "#00ff5f" }
        hl["@tag.attribute"] = { fg = "#9dff2e", italic = true }
        hl["@tag.delimiter"] = { fg = "#3a6244" }

        -- diagnostics: keep the squiggles readable on black
        hl.DiagnosticUnnecessary = { fg = "#3a6244", italic = true }

        -- statusline / tabs / explorer
        hl.StatusLine = { fg = "#8fd6a4", bg = "NONE" }
        hl.TabLineFill = { bg = "NONE" }
        hl.SnacksPickerDir = { fg = "#4a7d59" }
        hl.SnacksPickerMatch = { fg = "#9dff2e", bold = true }
        hl.SnacksIndent = { fg = "#16351f" }
        hl.SnacksIndentScope = { fg = "#1f8a44" }
      end,
    },
  },

  -- Make LazyVim actually load it.
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "tokyonight-night" },
  },
}
