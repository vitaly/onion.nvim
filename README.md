# onion.nvim

Layer your Neovim configuration like an onion - clean defaults with user overrides on top.

## Why?

If you maintain a Neovim config that others use (or even just yourself across
machines), you've probably run into this: you want sensible defaults, but you
also want to tweak things per-machine without editing the main config.

onion.nvim gives you a simple layered config system. Set your defaults once,
override them anywhere, and the merged result is always what you get. User
overrides can be saved to a file and loaded automatically.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'vitaly/onion.nvim',
  config = function()
    require('onion').setup({
      save_path = vim.fn.stdpath('config') .. '/config.lua',
    })
  end,
}
```

> `setup()` must be called before reading config — it loads saved user overrides
> from disk. Accessing config before `setup()` logs an error and returns defaults
> only. Calling `setup()` twice with different options throws an error; identical
> calls are safe.

## Quick Start

```lua
local config = require('onion')

-- Set some defaults (usually in your main config)
config.set_defaults('colorscheme', 'tokyonight')
config.set_defaults('formatting', {
  enabled = true,
  indent = 2,
})
config.set_defaults('lsp.servers', {
  lua_ls = {},
  rust_analyzer = { settings = { checkOnSave = true } },
})

-- Later, read the merged config
local scheme = config.get('colorscheme')  -- 'tokyonight'
local indent = config.get('formatting.indent')  -- 2

-- Override something (this goes into user overrides, not defaults)
config.set('colorscheme', 'gruvbox')
config.set('formatting.indent', 4)

-- Now get returns the overridden values
config.get('colorscheme')  -- 'gruvbox'
config.get('formatting.indent')  -- 4

-- But you can still check the original default
config.get_default('colorscheme')  -- 'tokyonight'
```

## Setup Options

```lua
require('onion').setup({
  -- Path to save/load user overrides (optional)
  save_path = vim.fn.stdpath('config') .. '/onion_user.lua',

  -- Log level for debugging (default: vim.log.levels.WARN)
  log_level = vim.log.levels.DEBUG,

  -- Auto-save user overrides on every change (default: false)
  auto_save = false,

  -- Auto-save when exiting Neovim (default: false)
  auto_save_on_exit = true,

  -- You can also pass defaults directly in setup
  defaults = {
    colorscheme = 'tokyonight',
    formatting = { enabled = true },
    ['lsp.timeout'] = 5000,
  },
})
```

## Commands

onion.nvim comes with an `:Onion` command for interactive use:

```vim
:Onion show                   " Show merged config
:Onion show formatting        " Show specific path
:Onion show --defaults        " Show only defaults
:Onion show --user            " Show only user overrides

:Onion reset                  " Reset all user overrides
:Onion reset formatting       " Reset specific path

:Onion save                   " Save user overrides to file
:Onion load                   " Load user overrides from file

:Onion edit                   " Open the config file in a split (auto-reloads on save)
```

## API

### Setting Values

```lua
-- Set defaults (usually done once in your config)
config.set_defaults('key', value)
config.set_defaults('nested.key', value)
config.set_defaults('lsp', { servers = { lua_ls = {} } })

-- Set user overrides (returns the merged value)
local current_value = config.set('key', value)
local nested_value = config.set('nested.key', value)
```

### Getting Values

```lua
-- Get merged value (defaults + user overrides)
config.get('key')
config.get('nested.key')

-- Get with default value (useful for toggling boolean settings)
config.get('feature.enabled', true)  -- Returns true if feature.enabled is not set

-- Example: toggling a setting with a default of true
config.set('something.enabled', not config.get('something.enabled', true))

-- Get only the default value
config.get_default('key')

-- Get only the user override (nil if not overridden)
config.get_user('key')
```

### Reset

```lua
-- Reset all user overrides (defaults are preserved, returns the defaults table)
local defaults = config.reset()

-- Reset specific path (returns the default value at that path)
local default_value = config.reset('formatting.indent')
```

### Toggle

```lua
-- Toggle a boolean value. returns the new value.
local new_value = config.toggle('feature.enabled')  -- toggles from default true to false

-- Toggle a boolean value, with default (used instead of nil current value). returns the new value
-- Assuming no value is set, toggle will set it to `false` first time around.
local new_value = config.toggle('feature.enabled', true)  -- toggles from default true to false

-- Toggle existing boolean value
config.set('debug.mode', false)
local enabled = config.toggle('debug.mode', false)  -- returns true, sets to true

-- Errors if the value is not boolean
config.set('invalid', 'string')
config.toggle('invalid', true)  -- throws error
```

### Save/Load

```lua
-- Save user overrides to file
config.save()  -- uses save_path from setup
config.save('/path/to/file.lua')

-- Load user overrides from file
config.load()  -- uses save_path from setup
config.load('/path/to/file.lua')
```

## How It Works

onion.nvim maintains three internal tables:

1. **defaults** - Set via `set_defaults()`, typically by plugin authors or your base config
2. **user** - Set via `set()`, these are your personal overrides
3. **merged** - Automatically computed by deep-merging defaults with user overrides

When you call `get()`, you always get from the merged table. User values take precedence over defaults.

The saved file is just a Lua table, so it's human-readable and editable:

```lua
return {
  colorscheme = "gruvbox",
  formatting = {
    indent = 4
  }
}
```

## lazy.nvim Pre-cloning

When using lazy.nvim, specs are evaluated before any plugin is cloned or loaded.
This means you **cannot** influence spec shape with onion — e.g.
`require(require('onion.config').get('completion.provider'))` or
`enabled = function() require('onion.config').get('telescope.enabled') end` will not
work, because onion.nvim may not even exist on disk yet at that point.

If you need to use onion values inside lazy specs, pre-clone onion.nvim **before**
lazy.nvim is loaded, the same way lazy.nvim itself is bootstrapped:

```lua
local onion_path = vim.fn.stdpath('data') .. '/lazy/onion.nvim'
if not (vim.uv or vim.loop).fs_stat(onion_path) then
  local repo = 'https://github.com/vitaly/onion.nvim.git'
  local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none', repo, onion_path })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone onion.nvim:\n', 'ErrorMsg' },
      { out, 'WarningMsg' },
      { '\nPress any key to exit...' },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(onion_path)

require('onion').setup({
  save_path = vim.fn.stdpath('config') .. '/config.lua',
  auto_save = true,
  defaults = {
    log_level = vim.log.levels.WARN,
  },
})
```

> If you use `dev = true` or `dir = '...'` in your lazy spec for onion.nvim,
> update `onion_path` above to match where lazy.nvim will look for it, otherwise
> they will be out of sync.

## License

MIT
