local ui = require('onion.ui')

local M = {}

local subcommands = {
  'show',
  'reset',
  'save',
  'load',
  'edit',
}

local show_options = {
  'merged',
  'defaults',
  'user',
}

---Parse arguments for the Onion command
---@param args string
---@return string? subcommand
---@return string[]? rest
local function parse_args(args)
  local parts = {}
  for part in string.gmatch(args, '%S+') do
    table.insert(parts, part)
  end
  local subcommand = parts[1]
  table.remove(parts, 1)
  return subcommand, parts
end

---Execute the Onion command
---@param opts table Command options from nvim_create_user_command
local function onion_command(opts)
  local subcommand, rest = parse_args(opts.args)

  if not subcommand then
    vim.notify('[onion] Usage: Onion <show|reset|save|load|edit> [args]', vim.log.levels.WARN)
    return
  end

  if subcommand == 'show' then
    -- Onion show [path] [--defaults|--user]
    local path = nil
    local what = 'merged'
    for _, arg in ipairs(rest) do
      if arg == '--defaults' then
        what = 'defaults'
      elseif arg == '--user' then
        what = 'user'
      else
        path = arg
      end
    end
    ui.show(path, what)
  elseif subcommand == 'reset' then
    -- Onion reset [path]
    ui.reset(rest[1])
  elseif subcommand == 'save' then
    ui.save()
  elseif subcommand == 'load' then
    ui.load()
  elseif subcommand == 'edit' then
    ui.edit()
  else
    vim.notify(
      string.format('[onion] Unknown subcommand: %s. Use: show, reset, save, load, edit', subcommand),
      vim.log.levels.ERROR
    )
  end
end

---Complete the Onion command
---@param arg_lead string
---@param cmd_line string
---@param cursor_pos number
---@return string[]
local function onion_complete(arg_lead, cmd_line, cursor_pos)
  local parts = {}
  for part in string.gmatch(cmd_line:sub(1, cursor_pos), '%S+') do
    table.insert(parts, part)
  end

  -- Check if we're still typing or have moved to next arg
  local on_space = cmd_line:sub(cursor_pos, cursor_pos) == ' '
  local num_args = #parts - 1 -- subtract 'Onion'
  if on_space then
    num_args = num_args + 1
  end

  if num_args <= 1 then
    -- Complete subcommand
    local matches = {}
    for _, cmd in ipairs(subcommands) do
      if cmd:find('^' .. vim.pesc(arg_lead)) then
        table.insert(matches, cmd)
      end
    end
    return matches
  end

  local subcommand = parts[2]

  if subcommand == 'show' then
    -- Complete --defaults, --user flags
    local matches = {}
    for _, opt in ipairs({ '--defaults', '--user' }) do
      if opt:find('^' .. vim.pesc(arg_lead)) then
        table.insert(matches, opt)
      end
    end
    return matches
  end

  return {}
end

---Setup the Onion command
function M.setup()
  vim.api.nvim_create_user_command('Onion', onion_command, {
    nargs = '*',
    complete = onion_complete,
    desc = 'Onion config management',
  })
end

return M
