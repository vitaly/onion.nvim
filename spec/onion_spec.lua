describe('onion.config', function()
  local config

  before_each(function()
    package.loaded['onion.config'] = nil
    config = require('onion.config')
    config.reset()
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
    it('clears all state', function()
      config.set_defaults('test', { value = 1 })
      config.set('test.other', 2)
      config.reset()

      assert.is_nil(config.get('test.value'))
      assert.is_nil(config.get('test.other'))
    end)
  end)
end)
