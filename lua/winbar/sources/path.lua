local utils = require('winbar.sources.utils')
local configs = require('winbar.configs')

---Unify a path into a winbar tree symbol tree structure
---@param path string full path
---@return winbar_path_symbol_tree_t
local function unify(path)
  return setmetatable({
    name = vim.fs.basename(path),
    kind = '',
    data = { path = path },
  }, {
    ---@param self winbar_symbol_tree_t
    __index = function(self, k)
      if k == 'children' then
        self.children = {}
        for name in vim.fs.dir(path) do
          table.insert(self.children, unify(path .. '/' .. name))
        end
        return self.children
      end
      if k == 'siblings' or k == 'idx' then
        local parent_dir = vim.fs.dirname(path)
        self.siblings = {}
        self.idx = 1
        for idx, name in vim.iter(vim.fs.dir(parent_dir)):enumerate() do
          table.insert(self.siblings, unify(parent_dir .. '/' .. name))
          if name == self.name then
            self.idx = idx
          end
        end
        return self[k]
      end
    end,
  })
end

---Get list of winbar symbols of the parent directories of given buffer
---@param buf integer buffer handler
---@param _ integer[] cursor position, ignored
---@return winbar_symbol_t[] winbar symbols
local function get_symbols(buf, _)
  local symbols = {} ---@type winbar_symbol_t[]
  local current_path = vim.fs.normalize(
    vim.fn.fnamemodify((vim.api.nvim_buf_get_name(buf)), ':p')
  )
  local base_path = vim.fn.finddir(vim.fn.fnamemodify(current_path, ":h"), vim.fn.getcwd())
  while
    current_path ~= '/'
    and current_path ~= base_path
    and current_path
      ~= configs.eval(configs.opts.sources.path.relative_to, buf)
  do
    table.insert(
      symbols,
      1,
      utils.to_winbar_symbol_from_path(unify(current_path))
    )
    current_path = vim.fs.dirname(current_path)
  end
  return symbols
end

return {
  get_symbols = get_symbols,
}
