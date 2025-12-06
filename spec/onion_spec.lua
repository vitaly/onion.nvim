---@diagnostic disable: need-check-nil, unused-local

local inspect = require('inspect')

---Deep copy implementation for test stub
---@param t any
---@return any
local function deepcopy(t)
  if type(t) ~= 'table' then
    return t
  end
  local result = {}
  for k, v in pairs(t) do
    result[k] = deepcopy(v)
  end
  return result
end

-- Stub vim global for busted tests
_G.vim = {
  log = {
    levels = {
      DEBUG = 1,
      INFO = 2,
      WARN = 3,
      ERROR = 4,
    },
  },
  notify = function(message, level)
    print('Vim Notify [' .. level .. ']: ' .. message)
  end,

  inspect = inspect,
  deepcopy = deepcopy,

  fn = {
    fnamemodify = function(path, mod)
      if mod == ':h' then
        return path:match('(.+)/[^/]+$') or '.'
      end
      return path
    end,
    ---@param path string
    isdirectory = function(path)
      return 1
    end,
    ---@param path string
    ---@param flags? string
    mkdir = function(path, flags) end,
  },
  api = {
    ---@param event string|string[]
    ---@param opts any
    nvim_create_autocmd = function(event, opts) end,
    ---@param name string
    ---@param opts any
    nvim_create_augroup = function(name, opts)
      return 1
    end,
  },
}

describe('onion.config', function()
  local config

  before_each(function()
    package.loaded['onion.config'] = nil
    config = require('onion.config')
    config.reset_all()
  end)

  describe('set_defaults', function()
    it('sets defaults for a namespace', function()
      config.set_defaults('formatting', { enabled = true })
      assert.are.equal(true, config.get('formatting.enabled'))
    end)

    it('merges multiple set_defaults calls', function()
      config.set_defaults('lsp', { ensure_installed = { 'bashls' } })
      config.set_defaults('lsp', { servers = { lua_ls = {} } })

      assert.are.same({ 'bashls' }, config.get('lsp.ensure_installed'))
      assert.are.same({}, config.get('lsp.servers.lua_ls'))
    end)

    it('deep merges nested tables', function()
      config.set_defaults('lsp', {
        servers = { ruby_lsp = { cmd = { 'ruby-lsp' } } },
      })
      config.set_defaults('lsp', {
        servers = { lua_ls = { settings = {} } },
      })

      assert.are.same({ 'ruby-lsp' }, config.get('lsp.servers.ruby_lsp.cmd'))
      assert.are.same({}, config.get('lsp.servers.lua_ls.settings'))
    end)
  end)

  describe('get', function()
    it('returns nil for non-existent paths', function()
      assert.is_nil(config.get('nonexistent'))
      assert.is_nil(config.get('nonexistent.nested.path'))
    end)

    it('returns values using dot notation', function()
      config.set_defaults('lsp', {
        servers = {
          ruby_lsp = { cmd = { 'ruby-lsp' } },
        },
      })
      assert.are.same({ cmd = { 'ruby-lsp' } }, config.get('lsp.servers.ruby_lsp'))
    end)
  end)

  describe('get_default', function()
    it('returns the default value even if user override exists', function()
      config.set_defaults('formatting', { enabled = true })
      config.set('formatting.enabled', false)

      assert.are.equal(true, config.get_default('formatting.enabled'))
      assert.are.equal(false, config.get('formatting.enabled'))
    end)
  end)

  describe('set', function()
    it('overrides default values', function()
      config.set_defaults('formatting', { enabled = true })
      config.set('formatting.enabled', false)

      assert.are.equal(false, config.get('formatting.enabled'))
    end)

    it('creates nested paths', function()
      config.set('new.nested.value', 42)
      assert.are.equal(42, config.get('new.nested.value'))
    end)

    it('merges with defaults', function()
      config.set_defaults('lsp', {
        ensure_installed = { 'bashls', 'stylua' },
        enable = { 'lua_ls' },
      })
      config.set('lsp.enable', { 'ts_ls' })

      assert.are.same({ 'bashls', 'stylua' }, config.get('lsp.ensure_installed'))
      assert.are.same({ 'ts_ls' }, config.get('lsp.enable'))
    end)
  end)

  describe('reset', function()
    it('clears user overrides but keeps defaults', function()
      config.set_defaults('test', { value = 1 })
      config.set('test.other', 2)
      config.reset()

      -- defaults are preserved
      assert.are.equal(1, config.get('test.value'))
      -- user overrides are cleared
      assert.is_nil(config.get('test.other'))
    end)

    it('resets only the specified user override path', function()
      config.set_defaults('formatting', { enabled = true })
      config.set_defaults('lsp', { servers = {} })
      config.set('formatting.enabled', false)
      config.set('lsp.extra', 'value')

      config.reset('formatting.enabled')

      -- reset user override, falls back to default
      assert.are.equal(true, config.get('formatting.enabled'))
      -- other user overrides preserved
      assert.are.equal('value', config.get('lsp.extra'))
    end)

    it('resets nested user override paths', function()
      config.set_defaults('lsp', {
        servers = {
          lua_ls = { cmd = { 'lua-language-server' } },
          ruby_lsp = { cmd = { 'ruby-lsp' } },
        },
      })
      config.set('lsp.servers.lua_ls.extra', 'user-value')

      config.reset('lsp.servers.lua_ls.extra')

      assert.is_nil(config.get('lsp.servers.lua_ls.extra'))
      -- defaults preserved
      assert.are.same({ 'lua-language-server' }, config.get('lsp.servers.lua_ls.cmd'))
    end)
  end)

  describe('get_user', function()
    it('returns only user overrides', function()
      config.set_defaults('test', { default_value = 1 })
      config.set('test.user_value', 2)

      assert.is_nil(config.get_user('test.default_value'))
      assert.are.equal(2, config.get_user('test.user_value'))
    end)
  end)

  describe('deep copy protection', function()
    it('get returns a copy that cannot modify internal state', function()
      config.set_defaults('test', { nested = { value = 1 } })

      local result = config.get('test.nested')
      result.value = 999

      assert.are.equal(1, config.get('test.nested.value'))
    end)

    it('get_default returns a copy that cannot modify internal state', function()
      config.set_defaults('test', { nested = { value = 1 } })

      local result = config.get_default('test.nested')
      result.value = 999

      assert.are.equal(1, config.get_default('test.nested.value'))
    end)

    it('get_user returns a copy that cannot modify internal state', function()
      config.set('test.nested.value', 1)

      local result = config.get_user('test.nested')
      result.value = 999

      assert.are.equal(1, config.get_user('test.nested.value'))
    end)
  end)

  describe('setup', function()
    it('stores options in defaults under onion.config', function()
      config.setup({
        log_level = vim.log.levels.DEBUG,
        auto_save = true,
      })

      assert.are.equal(vim.log.levels.DEBUG, config.get('onion.config.log_level'))
      assert.are.equal(true, config.get('onion.config.auto_save'))
    end)

    it('uses default values when not specified', function()
      config.setup({})

      assert.are.equal(vim.log.levels.WARN, config.get('onion.config.log_level'))
      assert.are.equal(false, config.get('onion.config.auto_save'))
      assert.are.equal(false, config.get('onion.config.auto_save_on_exit'))
    end)

    it('works with empty opts', function()
      config.setup()
      assert.are.equal(vim.log.levels.WARN, config.get('onion.config.log_level'))
    end)

    it('applies defaults from opts.defaults', function()
      config.setup({
        defaults = {
          formatting = { enabled = true, indent = 2 },
          lsp = { servers = { lua_ls = {} } },
        },
      })

      assert.are.equal(true, config.get('formatting.enabled'))
      assert.are.equal(2, config.get('formatting.indent'))
      assert.are.same({}, config.get('lsp.servers.lua_ls'))
    end)
  end)

  describe('save', function()
    local test_file = './test/onion_test_config.lua'

    after_each(function()
      os.remove(test_file)
    end)

    it('saves user config to specified path in Lua format', function()
      config.set('test.value', 42)
      local result = config.save(test_file)

      assert.is_true(result)

      local file = io.open(test_file, 'r')
      assert.is_not_nil(file)
      local content = file:read('*a')
      file:close()
      assert.is_truthy(content:match('return'))
      assert.is_truthy(content:match('42'))
    end)

    it('saves config that can be loaded with dofile', function()
      config.set('test.value', 42)
      config.set('test.name', 'hello')
      config.save(test_file)

      local loaded = dofile(test_file)
      assert.are.equal(42, loaded.test.value)
      assert.are.equal('hello', loaded.test.name)
    end)

    it('uses save_path from setup when no path given', function()
      config.setup({ save_path = test_file })
      config.set('test.value', 123)

      local result = config.save()
      assert.is_true(result)

      local file = io.open(test_file, 'r')
      assert.is_not_nil(file)
      file:close()
    end)

    it('fails when no path available', function()
      config.setup({})
      local result = config.save()
      assert.is_false(result)
    end)
  end)

  describe('load', function()
    local test_file = './test/onion_test_config.lua'

    after_each(function()
      os.remove(test_file)
    end)

    it('loads user config from specified path', function()
      -- Create a test file
      local file = io.open(test_file, 'w')
      file:write('return { test = { value = 42 } }\n')
      file:close()

      local result = config.load(test_file)

      assert.is_true(result)
      assert.are.equal(42, config.get('test.value'))
    end)

    it('uses save_path from setup when no path given', function()
      -- Create a test file
      local file = io.open(test_file, 'w')
      file:write('return { test = { loaded = true } }\n')
      file:close()

      config.setup({ save_path = test_file })
      -- reset user to clear what setup loaded
      config.reset()
      local result = config.load()

      assert.is_true(result)
      assert.are.equal(true, config.get('test.loaded'))
    end)

    it('fails when no path available', function()
      config.setup({})
      local result = config.load()
      assert.is_false(result)
    end)

    it('returns false for non-existent file', function()
      local result = config.load('/nonexistent/path/config.lua')
      assert.is_false(result)
    end)
  end)
end)
