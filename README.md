# Introduction

This is plugin for dynamic winbar modded from Bekaboo/nvim

## ⚡️ Requirements

- Neovim >= 0.9.0
- a [Nerd Font](https://www.nerdfonts.com/)

## 📦 Installation

Install the plugin with your preferred package manager:

```lua
-- Lazy
{
  "kiet231199/winbar.nvim",
  config = function()
    require("winbar").setup()
    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
      once = true,
      group = vim.api.nvim_create_augroup('WinBarSetup', {}),
      callback = function()
        local api = require('winbar.api')
        vim.keymap.set('n', '<space>w', api.pick)
      end,
    })
  end,
}
```

## ⚙️ Configuration

**winbar.nvim** comes with the following defaults:

```lua
local kinds = {
  Array             = ' ',
  Boolean           = ' ',
  BreakStatement    = '󰙧 ',
  Calculator        = ' ',
  Call              = ' ',
  CaseStatement     = ' ',
  Class             = ' ',
  Color             = ' ',
  Constant          = ' ',
  Constructor       = ' ',
  ContinueStatement = '→ ',
  Copilot           = ' ',
  Declaration       = ' ',
  Delete            = ' ',
  Desktop           = ' ',
  DoStatement       = ' ',
  Enum              = ' ',
  EnumMember        = ' ',
  Event             = ' ',
  Field             = ' ',
  File              = ' ',
  Folder            = ' ',
  ForStatement      = ' ',
  Format            = ' ',
  Function          = ' ',
  GitBranch         = ' ',
  Identifier        = ' ',
  IfStatement       = ' ',
  Interface         = ' ',
  Keyword           = ' ',
  List              = ' ',
  Log               = ' ',
  Lsp               = ' ',
  Macro             = ' ',
  Method            = ' ',
  Module            = ' ',
  Namespace         = ' ',
  Null              = ' ',
  Number            = ' ',
  Object            = ' ',
  Operator          = ' ',
  Package           = ' ',
  Property          = ' ',
  Reference         = ' ',
  Regex             = ' ',
  Repeat            = ' ',
  Scope             = ' ',
  Snippet           = ' ',
  Specifier         = ' ',
  Statement         = ' ',
  String            = ' ',
  Struct            = ' ',
  SwitchStatement   = ' ',
  Terminal          = ' ',
  Text              = ' ',
  Type              = ' ',
  TypeParameter     = ' ',
  Unit              = ' ',
  Value             = ' ',
  Variable          = ' ',
  WhileStatement    = ' ',
}

local ui = {
  AngleDown     = ' ',
  AngleLeft     = ' ',
  AngleRight    = ' ',
  AngleUp       = ' ',
  ArrowDown     = '↓ ',
  ArrowLeft     = '← ',
  ArrowRight    = '→ ',
  ArrowUp       = '↑ ',
  Cross         = ' ',
  Diamond       = '◆ ',
  Dot           = '• ',
  DotLarge      = ' ',
  Ellipsis      = '… ',
  Indicator     = '',
  Pin           = ' ',
  Separator     = '  ',
  TriangleDown  = '▼ ',
  TriangleLeft  = '◀ ',
  TriangleRight = '▶ ',
  TriangleUp    = '▲ ',
}

require('winbar').setup({
  symbol = {
    icons = {
      kinds = kinds,
      ui = ui,
    },
  },
  bar = {
    pick = {
      -- Characters to select level
      pivots = '1234567890abcdefghijklmnopqrstuvwxyz',
    },
  },
  menu = {
    keymaps = {
      ['<LeftMouse>'] = function()
        local api = require('winbar.api')
        local menu = api.get_current_winbar_menu()
        if not menu then
          return
        end
        local mouse = vim.fn.getmousepos()
        if mouse.winid ~= menu.win then
          local parent_menu = api.get_winbar_menu(mouse.winid)
          if parent_menu and parent_menu.sub_menu then
            parent_menu.sub_menu:close()
          end
          if vim.api.nvim_win_is_valid(mouse.winid) then
            vim.api.nvim_set_current_win(mouse.winid)
          end
          return
        end
        menu:click_at({ mouse.line, mouse.column })
      end,
      ['<CR>'] = function()
        local menu = require('winbar.api').get_current_winbar_menu()
        if not menu then
          return
        end
        local cursor = vim.api.nvim_win_get_cursor(menu.win)
        local component = menu.entries[cursor[1]]:first_clickable(cursor[2])
        if component then
          menu:click_on(component)
        end
      end,
      ['q'] = function()
        local menu = require('winbar.api').get_current_winbar_menu()
        if not menu then
          return
        end
        local cursor = vim.api.nvim_win_get_cursor(menu.win)
        local component = menu.entries[cursor[1]]:first_clickable(cursor[2])
        if component then
          menu:close()
        end
      end,
    },
    win_configs = {
      -- Choose one of border style below:
      -- rounded, single, vintage, rounded_clc, single_clc, vintage_clc, empty
      -- double, double_header, double_bottom, double_horizontal, double_left, double_right, double_vertical,
      -- double_clc, double_header_clc, double_bottom_clc, double_horizontal_clc, double_left_clc, double_right_clc, double_vertical_clc,
      border = 'rounded',
      style = 'minimal',

      -- Width and height should be default
      -- height = 10,
      -- width = 10,
    },
  },
})
```

