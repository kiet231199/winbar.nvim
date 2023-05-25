local static = require('winbar.utils.static')
local M = {}

---@class winbar_configs_t
M.opts = {
  general = {
    ---@type boolean|fun(buf: integer, win: integer): boolean
    enable = function(buf, win)
      return not vim.api.nvim_win_get_config(win).zindex
        and vim.bo[buf].buftype == ''
        and vim.api.nvim_buf_get_name(buf) ~= ''
        and not vim.wo[win].diff
    end,
    update_events = {
      'CursorHold',
      'CursorHoldI',
      'DirChanged',
      'FileChangedShellPost',
      'TextChanged',
      'VimResized',
      'WinResized',
      'WinScrolled',
    },
  },
  symbol = {
    icons = {
      kinds = static.icons.kinds,
      ui = static.icons.ui,
    },
  },
  bar = {
    ---@type winbar_source_t[]|fun(buf: integer, win: integer): winbar_source_t[]
    sources = function(_, _)
      local sources = require('winbar.sources')
      return {
        sources.path,
        {
          get_symbols = function(buf, cursor)
            for _, source in ipairs({
              sources.lsp,
              sources.treesitter,
              sources.markdown,
            }) do
              local symbols = source.get_symbols(buf, cursor)
              if not vim.tbl_isempty(symbols) then
                return symbols
              end
            end
            return {}
          end,
        },
      }
    end,
    pick = {
      pivots = '1234567890abcdefghijklmnopqrstuvwxyz',
    },
  },
  menu = {
    ---@type table<string, function|table<string, function>>
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
    ---@alias winbar_menu_win_config_opts_t any|fun(menu: winbar_menu_t):any
    ---@type table<string, winbar_menu_win_config_opts_t>
    ---@see vim.api.nvim_open_win
    win_configs = {
      border = 'rounded',
      style = 'minimal',
      row = function(menu)
        return menu.parent_menu
            and menu.parent_menu.clicked_at
            and menu.parent_menu.clicked_at[1] - vim.fn.line('w0')
          or 1
      end,
      col = function(menu)
        return menu.parent_menu and menu.parent_menu._win_configs.width + 1 or 0
      end,
      relative = function(menu)
        return menu.parent_menu and 'win' or 'mouse'
      end,
      win = function(menu)
        return menu.parent_menu and menu.parent_menu.win
      end,
      height = function(menu)
        return math.max(
          1,
          math.min(
            #menu.entries,
            vim.go.pumheight ~= 0 and vim.go.pumheight
              or math.ceil(vim.go.lines / 4)
          )
        )
      end,
      width = function(menu)
        local min_width = vim.go.pumwidth ~= 0 and vim.go.pumwidth or 10
        if vim.tbl_isempty(menu.entries) then
          return min_width
        end
        return math.max(
          min_width,
          math.max(unpack(vim.tbl_map(function(entry)
            return entry:displaywidth()
          end, menu.entries)))
        )
      end,
    },
  },
  sources = {
    path = {
      ---@type string|fun(buf: integer): string
      relative_to = function(buf)
        return require('winbar.utils.funcs.fs').proj_dir(
          vim.api.nvim_buf_get_name(buf)
        ) or vim.fn.getcwd()
      end,
    },
  },
}

---Set winbar options
---@param new_opts winbar_configs_t?
function M.set(new_opts)
  M.opts = vim.tbl_deep_extend('force', M.opts, new_opts or {})
end

---Evaluate a dynamic option value (with type T|fun(...): T)
---@generic T
---@param opt T|fun(...): T
---@return T
function M.eval(opt, ...)
  if type(opt) == 'function' then
    return opt(...)
  end
  return opt
end

return M
