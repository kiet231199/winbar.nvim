---Get the winbar
---@param buf integer
---@param win integer
---@return winbar_t?
local function get_winbar(buf, win)
  if rawget(_G.winbar.bars, buf) then
    return rawget(_G.winbar.bars[buf], win)
  end
end

---Get current winbar
---@return winbar_t?
local function get_current_winbar()
  return get_winbar(
    vim.api.nvim_get_current_buf(),
    vim.api.nvim_get_current_win()
  )
end

---Get winbar menu
---@param win integer
---@return winbar_menu_t?
local function get_winbar_menu(win)
  return _G.winbar.menus[win]
end

---Get current winbar menu
---@return winbar_menu_t?
local function get_current_winbar_menu()
  return get_winbar_menu(vim.api.nvim_get_current_win())
end

---Goto the start of context
---If `count` is 0, goto the start of current context, or the start ot
---prev context if cursor is already at the start of current context;
---If `count` is positive, goto the start of `count` prev context
---@param count integer? default vim.v.count
local function goto_context_start(count)
  count = count or vim.v.count
  local bar = get_current_winbar()
  if not bar or not bar.components or vim.tbl_isempty(bar.components) then
    return
  end
  local current_sym = bar.components[#bar.components]
  if
    not current_sym.symbol
    or not current_sym
    or not current_sym.symbol.range
  then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  if
    count == 0
    and current_sym.symbol.range.start.line == cursor[1] - 1
    and current_sym.symbol.range.start.character == cursor[2]
  then
    count = count + 1
  end
  while count > 0 do
    count = count - 1
    local prev_sym = bar.components[current_sym.bar_idx - 1]
    if not prev_sym or not prev_sym.symbol or not prev_sym.symbol.range then
      break
    end
    current_sym = prev_sym
  end
  current_sym:goto_start()
end

---Open the menu of current context to select the next context
local function select_next_context()
  local bar = get_current_winbar()
  if not bar or not bar.components or vim.tbl_isempty(bar.components) then
    return
  end
  bar.in_pick_mode = true
  bar.components[#bar.components]:on_click()
  bar.in_pick_mode = false
end

---Pick a component from current winbar
local function pick()
  local bar = get_current_winbar()
  if bar then
    bar:pick()
  end
end

return {
  get_winbar = get_winbar,
  get_current_winbar = get_current_winbar,
  get_winbar_menu = get_winbar_menu,
  get_current_winbar_menu = get_current_winbar_menu,
  goto_context_start = goto_context_start,
  select_next_context = select_next_context,
  pick = pick,
}
