---@class OnionSetupOpts
---@field save_path? string Path to save and load user overrides
---@field log_level? number Log level for debugging (vim.log.levels.*)
---@field auto_save? boolean Automatically save on every change (default: false)
---@field auto_save_on_exit? boolean Automatically save on nvim exit (default: false)
---@field defaults? table<string, any> Default values to set (path -> value)

---@class OnionConfig
---@field private _defaults table
---@field private _user table
---@field private _merged table
local M = {}

M._defaults = {}
M._user = {}
M._merged = {}

---Log a message at the specified level
---@param level number
---@param msg string
---@param ... any
local function log(level, msg, ...)
  local log_level = M._merged.onion and M._merged.onion.config and M._merged.onion.config.log_level
    or vim.log.levels.WARN
  if level < log_level then
    return
  end

  vim.notify('[onion] ' .. string.format(msg, ...), level)
end

---Deep merge two tables, with t2 values taking precedence
---@param t1 table
---@param t2 table
---@return table
local function deep_merge(t1, t2)
  local result = {}
  for k, v in pairs(t1) do
    if type(v) == 'table' then
      result[k] = deep_merge(v, {})
    else
      result[k] = v
    end
  end
  for k, v in pairs(t2) do
    if type(v) == 'table' and type(result[k]) == 'table' then
      result[k] = deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

---Update the merged table from defaults and user tables
local function update_merged()
  M._merged = deep_merge(M._defaults, M._user)
end

---Parse a dot-separated path into table keys
---@param path string
---@return string[]
local function parse_path(path)
  local keys = {}
  for key in string.gmatch(path, '[^.]+') do
    table.insert(keys, key)
  end
  return keys
end

---Get a value from a table using dot notation path
---@param tbl table
---@param path string
---@return any
local function get_by_path(tbl, path)
  local keys = parse_path(path)
  local current = tbl
  for _, key in ipairs(keys) do
    if type(current) ~= 'table' then
      return nil
    end
    current = current[key]
  end
  return current
end

---Set a value in a table using dot notation path
---@param tbl table
---@param path string
---@param value any
local function set_by_path(tbl, path, value)
  local keys = parse_path(path)
  local current = tbl
  for i = 1, #keys - 1 do
    local key = keys[i]
    if current[key] == nil then
      current[key] = {}
    end
    current = current[key]
  end
  current[keys[#keys]] = value
end

---Delete a value from a table using dot notation path
---@param tbl table
---@param path string
---@return boolean success
local function delete_by_path(tbl, path)
  local keys = parse_path(path)
  local current = tbl
  for i = 1, #keys - 1 do
    local key = keys[i]
    if type(current[key]) ~= 'table' then
      return false
    end
    current = current[key]
  end
  if current[keys[#keys]] ~= nil then
    current[keys[#keys]] = nil
    return true
  end
  return false
end

---Trigger auto-save if enabled
local function maybe_auto_save()
  if M.get('onion.config.auto_save') then
    log(vim.log.levels.DEBUG, 'auto-saving user config')
    M.save()
  end
end

---Set default value(s) using dot notation path
---@param path string Dot-notation path (e.g., 'colorscheme' or 'lsp.servers')
---@param value any The default value (can be any type)
function M.set_defaults(path, value)
  log(vim.log.levels.DEBUG, 'setting defaults for path: %s', path)
  if type(value) == 'table' then
    local existing = get_by_path(M._defaults, path)
    if type(existing) == 'table' then
      set_by_path(M._defaults, path, deep_merge(existing, value))
    else
      set_by_path(M._defaults, path, value)
    end
  else
    set_by_path(M._defaults, path, value)
  end
  update_merged()
end

---Get a value from the merged config using dot notation
---@param path string
---@param default? any Default value to return if path doesn't exist
---@return any
function M.get(path, default)
  local value = get_by_path(M._merged, path)
  if value == nil then
    return default
  end
  return vim.deepcopy(value)
end

---Get a value from the defaults using dot notation
---@param path string
---@return any
function M.get_default(path)
  return vim.deepcopy(get_by_path(M._defaults, path))
end

---Get a value from the user overrides using dot notation
---@param path string
---@return any
function M.get_user(path)
  return vim.deepcopy(get_by_path(M._user, path))
end

---Set a user value using dot notation
---@param path string
---@param value any
function M.set(path, value)
  log(vim.log.levels.DEBUG, 'setting user config: %s', path)
  set_by_path(M._user, path, value)
  update_merged()
  maybe_auto_save()
end

---Reset user overrides
---@param path? string Optional path to reset. If nil, resets all user overrides.
function M.reset(path)
  if path == nil then
    log(vim.log.levels.DEBUG, 'resetting all user overrides')
    M._user = {}
    update_merged()
  else
    log(vim.log.levels.DEBUG, 'resetting user override at path: %s', path)
    delete_by_path(M._user, path)
    update_merged()
  end
end

---Reset all config state including defaults (useful for testing)
function M.reset_all()
  log(vim.log.levels.DEBUG, 'resetting all config state')
  M._defaults = {}
  M._user = {}
  M._merged = {}
end

---Load user overrides from a Lua file
---@param path? string Optional path. If nil, uses the path from setup options.
---@return boolean success
function M.load(path)
  local load_path = path or M.get('onion.config.save_path')
  if not load_path then
    log(vim.log.levels.ERROR, 'load() called without path and no save_path configured in setup')
    return false
  end

  local file = io.open(load_path, 'r')
  if not file then
    log(vim.log.levels.DEBUG, 'no saved config found at: %s', load_path)
    return false
  end
  file:close()

  local ok, data = pcall(dofile, load_path)
  if not ok or type(data) ~= 'table' then
    log(vim.log.levels.ERROR, 'failed to parse saved config at: %s', load_path)
    return false
  end

  log(vim.log.levels.INFO, 'loaded user config from: %s', load_path)
  M._user = deep_merge(M._user, data)
  update_merged()
  return true
end

---Save user overrides to a Lua file
---@param path? string Optional path. If nil, uses the path from setup options.
---@return boolean success
function M.save(path)
  local save_path = path or M.get('onion.config.save_path')
  if not save_path then
    log(vim.log.levels.ERROR, 'save() called without path and no save_path configured in setup')
    return false
  end

  -- Create parent directories if needed
  local dir = vim.fn.fnamemodify(save_path, ':h')
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, 'p')
  end

  local file = io.open(save_path, 'w')
  if not file then
    log(vim.log.levels.ERROR, 'failed to open file for writing: %s', save_path)
    return false
  end

  local lua_str = vim.inspect(M._user, { newline = '\n', indent = '  ' })
  file:write('return ' .. lua_str .. '\n')
  file:close()
  log(vim.log.levels.INFO, 'saved user config to: %s', save_path)
  return true
end

---Setup the plugin with options
---@param opts? OnionSetupOpts
function M.setup(opts)
  opts = opts or {}

  -- Store setup options in defaults under onion.config
  local config_defaults = {
    save_path = opts.save_path,
    log_level = opts.log_level or vim.log.levels.WARN,
    auto_save = opts.auto_save or false,
    auto_save_on_exit = opts.auto_save_on_exit or false,
  }
  M.set_defaults('onion.config', config_defaults)

  -- Apply user-provided defaults
  if opts.defaults then
    for namespace, defaults in pairs(opts.defaults) do
      M.set_defaults(namespace, defaults)
    end
  end

  log(vim.log.levels.DEBUG, 'setup called with opts: %s', vim.inspect(opts))

  -- Load user overrides from save_path if configured
  if opts.save_path then
    M.load(opts.save_path)
  end

  -- Setup auto-save on exit if enabled
  if opts.auto_save_on_exit then
    vim.api.nvim_create_autocmd('VimLeavePre', {
      group = vim.api.nvim_create_augroup('OnionAutoSave', { clear = true }),
      callback = function()
        log(vim.log.levels.DEBUG, 'auto-saving on exit')
        M.save()
      end,
    })
  end
end

return M
