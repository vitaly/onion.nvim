---@class OnionConfig
---@field private _defaults table
---@field private _user table
---@field private _merged table
local M = {}

M._defaults = {}
M._user = {}
M._merged = {}

---Deep merge two tables, with t2 values taking precedence
---@param t1 table
---@param t2 table
---@return table
local function deep_merge(t1, t2)
  local result = {}
  for k, v in pairs(t1) do
    if type(v) == "table" then
      result[k] = deep_merge(v, {})
    else
      result[k] = v
    end
  end
  for k, v in pairs(t2) do
    if type(v) == "table" and type(result[k]) == "table" then
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
  for key in string.gmatch(path, "[^.]+") do
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
    if type(current) ~= "table" then
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

---Set default values for a namespace
---@param namespace string
---@param defaults table
function M.set_defaults(namespace, defaults)
  if M._defaults[namespace] == nil then
    M._defaults[namespace] = {}
  end
  M._defaults[namespace] = deep_merge(M._defaults[namespace], defaults)
  update_merged()
end

---Get a value from the merged config using dot notation
---@param path string
---@return any
function M.get(path)
  return get_by_path(M._merged, path)
end

---Get a value from the defaults using dot notation
---@param path string
---@return any
function M.get_default(path)
  return get_by_path(M._defaults, path)
end

---Set a user value using dot notation
---@param path string
---@param value any
function M.set(path, value)
  set_by_path(M._user, path, value)
  update_merged()
end

---Reset all config state (useful for testing)
function M.reset()
  M._defaults = {}
  M._user = {}
  M._merged = {}
end

return M
