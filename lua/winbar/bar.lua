local configs = require('winbar.configs')

---Add highlight to a string
---@param str string
---@param hlgroup string?
---@return string
local function hl(str, hlgroup)
  if not hlgroup or hlgroup:match('^%s*$') then
    return str
  end
  return string.format('%%#%s#%s%%*', hlgroup, str or '')
end

---Make a winbar string clickable
---@param str string
---@param callback string
---@return string
local function make_clickable(str, callback)
  return string.format('%%@%s@%s%%X', callback, str)
end

---@class winbar_symbol_t
---@field name string
---@field icon string
---@field name_hl string?
---@field icon_hl string?
---@field bar winbar_t? the winbar the symbol belongs to, if the symbol is shown inside a winbar
---@field menu winbar_menu_t? menu associated with the winbar symbol, if the symbol is shown inside a winbar
---@field entry winbar_menu_entry_t? the winbar entry the symbol belongs to, if the symbol is shown inside a menu
---@field symbol winbar_symbol_tree_t? the symbol associated with the winbar symbol
---@field data table? any data associated with the symbol
---@field bar_idx integer? index of the symbol in the winbar
---@field entry_idx integer? index of the symbol in the menu entry
---@field on_click fun(this: winbar_symbol_t, min_width: integer?, n_clicks: integer?, button: string?, modifiers: string?)|false? force disable on_click when false
local winbar_symbol_t = {}
winbar_symbol_t.__index = winbar_symbol_t

---Create a winbar symbol instance
---@param opts winbar_symbol_t?
---@return winbar_symbol_t
function winbar_symbol_t:new(opts)
  return setmetatable(
    vim.tbl_deep_extend('force', {
      name = '',
      icon = '',
    }, opts or {}),
    winbar_symbol_t
  )
end

---Delete a winbar symbol instance
---@return nil
function winbar_symbol_t:del()
  if self.menu then
    self.menu:del()
  end
end

---Concatenate inside a winbar symbol to get the final string
---@param plain boolean?
---@return string
function winbar_symbol_t:cat(plain)
  if plain then
    return self.icon .. self.name
  end
  local icon_highlighted = hl(self.icon, self.icon_hl)
  local name_highlighted = hl(self.name, self.name_hl)
  if self.on_click and self.bar_idx then
    return make_clickable(
      icon_highlighted .. name_highlighted,
      string.format(
        'v:lua.winbar.on_click_callbacks.buf%s.win%s.fn%s',
        self.bar.buf,
        self.bar.win,
        self.bar_idx
      )
    )
  end
  return icon_highlighted .. name_highlighted
end

---Get the display length of the winbar symbol
---@return number
function winbar_symbol_t:displaywidth()
  return vim.fn.strdisplaywidth(self:cat(true))
end

---Get the byte length of the winbar symbol
---@return number
function winbar_symbol_t:bytewidth()
  return #self:cat(true)
end

---Goto the start location of the symbol associated with the winbar symbol
---@return nil
function winbar_symbol_t:goto_start()
  if not self.symbol or not self.symbol.range then
    return
  end
  local dest_pos = self.symbol.range.start
  if not self.entry then -- symbol is not shown inside a menu
    vim.api.nvim_win_set_cursor(self.bar.win, {
      dest_pos.line + 1,
      dest_pos.character,
    })
    return
  end
  -- symbol is shown inside a menu
  local current_menu = self.entry.menu
  while current_menu and current_menu.parent_menu do
    current_menu = current_menu.parent_menu
  end
  if current_menu then
    vim.api.nvim_win_set_cursor(current_menu.prev_win, {
      dest_pos.line + 1,
      dest_pos.character,
    })
    current_menu:close()
  end
end

---Temporarily change the content of a winbar symbol
---@param field string
---@param new_val any
function winbar_symbol_t:swap_field(field, new_val)
  self.data = self.data or {}
  self.data.swap = self.data.swap or {}
  self.data.swap[field] = self.data.swap[field] or self[field]
  self[field] = new_val
end

---Restore the content of a winbar symbol
function winbar_symbol_t:restore()
  if not self.data or not self.data.swap then
    return
  end
  for field, val in pairs(self.data.swap) do
    self[field] = val
  end
  self.data.swap = nil
end

---@class winbar_opts_t
---@field buf integer?
---@field win integer?
---@field sources winbar_source_t[]?
---@field separator winbar_symbol_t?
---@field extends winbar_symbol_t?
---@field padding {left: integer, right: integer}?

---@class winbar_t
---@field buf integer
---@field win integer
---@field sources winbar_source_t[]
---@field separator winbar_symbol_t
---@field padding {left: integer, right: integer}
---@field extends winbar_symbol_t
---@field components winbar_symbol_t[]
---@field string_cache string
---@field in_pick_mode boolean?
local winbar_t = {}
winbar_t.__index = winbar_t

---Create a winbar instance
---@param opts winbar_opts_t?
---@return winbar_t
function winbar_t:new(opts)
  local winbar = setmetatable(
    vim.tbl_deep_extend('force', {
      buf = vim.api.nvim_get_current_buf(),
      win = vim.api.nvim_get_current_win(),
      components = {},
      string_cache = '',
      sources = {},
      separator = winbar_symbol_t:new({
        icon = configs.opts.symbol.icons.ui.Separator,
        icon_hl = 'WinBarIconUISeparator',
      }),
      extends = winbar_symbol_t:new({
        icon = configs.opts.symbol.icons.ui.Extends
          or vim.opt.listchars:get().extends,
      }),
      padding = {
        left = 1,
        right = 1,
      },
    }, opts or {}),
    winbar_t
  )
  return winbar
end

---Delete a winbar instance
---@return nil
function winbar_t:del()
  _G.winbar.bars[self.buf][self.win] = nil
  _G.winbar.on_click_callbacks[self.buf][self.win] = nil
  for _, component in ipairs(self.components) do
    component:del()
  end
end

---Get the display length of the winbar
---@return number
function winbar_t:displaywidth()
  return vim.fn.strdisplaywidth(self:cat(true))
end

---Truncate the winbar to fit the window width
---Side effect: change winbar.components
---@return nil
function winbar_t:truncate()
  local win_width = vim.api.nvim_win_get_width(self.win)
  local len = self:displaywidth()
  local delta = len - win_width
  for _, component in ipairs(self.components) do
    if delta <= 0 then
      break
    end
    local name_len = vim.fn.strdisplaywidth(component.name)
    local min_len =
      vim.fn.strdisplaywidth(component.name:sub(1, 1) .. self.extends.icon)
    if name_len > min_len then
      component.name = vim.fn.strcharpart(
        component.name,
        0,
        math.max(1, name_len - delta - 1)
      ) .. self.extends.icon
      delta = delta - name_len + vim.fn.strdisplaywidth(component.name)
    end
  end
end

---Concatenate winbar into a string with separator and highlight
---@param plain boolean?
---@return string
function winbar_t:cat(plain)
  if vim.tbl_isempty(self.components) then
    return ''
  end
  local result = nil
  for _, component in ipairs(self.components) do
    result = result
        and result .. self.separator:cat(plain) .. component:cat(plain)
      or component:cat(plain)
  end
  -- Must add highlights to padding, else nvim will automatically truncate it
  local padding_hl = not plain and 'WinBar' or nil
  local padding_left = hl(string.rep(' ', self.padding.left), padding_hl)
  local padding_right = hl(string.rep(' ', self.padding.right), padding_hl)
  return result and padding_left .. result .. padding_right or ''
end

---Reevaluate winbar string from components and redraw winbar
---@return nil
function winbar_t:redraw()
  self:truncate()
  self.string_cache = self:cat()
  vim.cmd.redrawstatus()
end

---Update winbar components from sources and redraw winbar, supposed to be
---called at CursorMoved, CurosrMovedI, TextChanged, and TextChangedI
---Not updating when executing a macro
---@return nil
function winbar_t:update()
  if not self.win or not vim.api.nvim_win_is_valid(self.win) then
    self:del()
    return
  end
  if vim.fn.reg_executing() ~= '' or self.in_pick_mode then
    return self.string_cache
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  for _, component in ipairs(self.components) do
    component:del()
  end
  self.components = {}
  _G.winbar.on_click_callbacks['buf' .. self.buf]['win' .. self.win] = {}
  for _, source in ipairs(self.sources) do
    local symbols = source.get_symbols(self.buf, cursor)
    for _, symbol in ipairs(symbols) do
      symbol.bar_idx = #self.components + 1
      symbol.bar = self
      table.insert(self.components, symbol)
      -- Register on_click callback for each symbol
      if symbol.on_click then
        ---@param min_width integer 0 if no N specified
        ---@param n_clicks integer number of clicks
        ---@param button string mouse button used
        ---@param modifiers string modifiers used
        ---@return nil
        _G.winbar.on_click_callbacks['buf' .. self.buf]['win' .. self.win]['fn' .. symbol.bar_idx] = function(
          min_width,
          n_clicks,
          button,
          modifiers
        )
          symbol:on_click(min_width, n_clicks, button, modifiers)
        end
      end
    end
  end
  self:redraw()
end

---Pick a component from winbar
---Side effect: change winbar.in_pick_mode, winbar.components
---@return nil
function winbar_t:pick()
  if #self.components == 0 then
    return
  end
  self.in_pick_mode = true
  -- If has only one component, pick it directly
  if #self.components == 1 then
    self.components[1]:on_click()
    self.in_pick_mode = false
    return
  end
  -- Else Assign the chars on each component and wait for user input to pick
  local shortcuts = {}
  local pivots = {}
  for i = 1, #configs.opts.bar.pick.pivots do
    table.insert(pivots, configs.opts.bar.pick.pivots:sub(i, i))
  end
  local n_chars = math.ceil(math.log(#self.components, #pivots))
  for exp = 0, n_chars - 1 do
    for i = 1, #self.components do
      local new_char =
        pivots[math.floor((i - 1) / (#pivots) ^ exp) % #pivots + 1]
      shortcuts[i] = new_char .. (shortcuts[i] or '')
    end
  end
  -- Display the chars on each component
  for i, component in ipairs(self.components) do
    local shortcut = shortcuts[i]
    local icon_width = vim.fn.strdisplaywidth(component.icon)
    component:swap_field(
      'icon',
      shortcut .. string.rep(' ', icon_width - #shortcut)
    )
    component:swap_field('icon_hl', 'WinBarIconUIPickPivot')
  end
  self:redraw()
  -- Read the input from user
  local shortcut_read = ''
  for _ = 1, n_chars do
    shortcut_read = shortcut_read .. vim.fn.nr2char(vim.fn.getchar())
  end
  -- Restore the original content of each component
  for _, component in ipairs(self.components) do
    component:restore()
  end
  self:redraw()
  -- Execute the on_click callback of the component
  for i, shortcut in ipairs(shortcuts) do
    if shortcut == shortcut_read then
      self.components[i]:on_click()
      break
    end
  end
  self.in_pick_mode = false
end

---Get the string representation of the winbar
---@return string
function winbar_t:__tostring()
  if vim.tbl_isempty(self.components) then
    self:update()
  end
  return self.string_cache
end

return {
  winbar_t = winbar_t,
  winbar_symbol_t = winbar_symbol_t,
}
