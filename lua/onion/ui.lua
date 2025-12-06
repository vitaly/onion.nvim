local config = require('onion.config')

local M = {}

---Show config values
---@param path? string Optional path to show
---@param what? string What to show: 'merged' (default), 'defaults', 'user'
function M.show(path, what)
  what = what or 'merged'

  local value
  local label
  if what == 'defaults' then
    value = path and config.get_default(path) or config.get_default('')
    label = 'defaults'
  elseif what == 'user' then
    value = path and config.get_user(path) or config.get_user('')
    label = 'user overrides'
  else
    value = path and config.get(path) or config.get('')
    label = 'merged config'
  end

  if value == nil then
    if path then
      print(string.format('[onion] %s: %s is nil', label, path))
    else
      print(string.format('[onion] %s is empty', label))
    end
    return
  end

  local display = vim.inspect(value, { newline = '\n', indent = '  ' })
  if path then
    print(string.format('[onion] %s: %s =\n%s', label, path, display))
  else
    print(string.format('[onion] %s:\n%s', label, display))
  end
end

---Reset user overrides
---@param path? string Optional path to reset
function M.reset(path)
  config.reset(path)
  if path then
    print(string.format('[onion] reset user override: %s', path))
  else
    print('[onion] reset all user overrides')
  end
end

---Save user overrides to file
function M.save()
  local save_path = config.get('onion.config.save_path')
  if config.save() then
    print(string.format('[onion] saved to: %s', save_path))
  end
end

---Load user overrides from file
function M.load()
  local load_path = config.get('onion.config.save_path')
  if config.load() then
    print(string.format('[onion] loaded from: %s', load_path))
  end
end

---Edit the config file
function M.edit()
  local save_path = config.get('onion.config.save_path')
  if not save_path then
    vim.notify('[onion] no save_path configured in setup', vim.log.levels.ERROR)
    return
  end

  -- Save current config first
  config.save()

  -- Open in a split
  vim.cmd('split ' .. vim.fn.fnameescape(save_path))

  -- Setup autocmd to reload on save
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_create_autocmd('BufWritePost', {
    buffer = bufnr,
    callback = function()
      -- Clear user config and reload from file
      config.reset()
      config.load()
      vim.notify('[onion] config reloaded', vim.log.levels.INFO)
    end,
  })
end

return M
