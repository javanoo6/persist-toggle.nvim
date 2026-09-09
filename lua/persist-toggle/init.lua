local M = {}

local DEFAULT_CONFIG = {
  path = vim.fn.stdpath("state") .. "/persist-toggle/state.json",
  toggles = {},
  notify = true,
  apply_on_setup = true,
}

local config = vim.deepcopy(DEFAULT_CONFIG)
local registry = {}
local state = {
  version = 1,
  values = {},
}

local function notify(message, level)
  if config.notify then
    vim.notify(message, level or vim.log.levels.INFO, { title = "persist-toggle.nvim" })
  end
end

local function copy(value)
  return vim.deepcopy(value)
end

local function normalize_path(path)
  return vim.fn.fnamemodify(path, ":p")
end

local function ensure_parent_dir(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  if dir and dir ~= "" then
    vim.fn.mkdir(dir, "p")
  end
end

local function read_file(path)
  local fd = vim.uv.fs_open(path, "r", 438)
  if not fd then
    return nil
  end

  local stat = vim.uv.fs_fstat(fd)
  local data = ""
  if stat and stat.size > 0 then
    data = vim.uv.fs_read(fd, stat.size, 0) or ""
  end
  vim.uv.fs_close(fd)
  return data
end

local function write_file(path, data)
  ensure_parent_dir(path)
  local fd, err = vim.uv.fs_open(path, "w", 420)
  if not fd then
    error(("failed to open %s: %s"):format(path, err or "unknown error"))
  end

  local ok, write_err = vim.uv.fs_write(fd, data, 0)
  vim.uv.fs_close(fd)
  if not ok then
    error(("failed to write %s: %s"):format(path, write_err or "unknown error"))
  end
end

local function decode_state(raw)
  if not raw or raw == "" then
    return { version = 1, values = {} }
  end

  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or type(decoded) ~= "table" then
    notify("Ignoring invalid state file", vim.log.levels.WARN)
    return { version = 1, values = {} }
  end

  if type(decoded.values) ~= "table" then
    decoded.values = {}
  end

  decoded.version = 1
  return decoded
end

local function encode_state()
  return vim.json.encode({
    version = 1,
    values = state.values,
  })
end

local function assert_id(id)
  if type(id) ~= "string" or id == "" then
    error("toggle id must be a non-empty string", 3)
  end
end

local function assert_toggle(id)
  local toggle = registry[id]
  if not toggle then
    error(("unknown toggle: %s"):format(id), 3)
  end
  return toggle
end

local function validate_spec(id, spec)
  if type(spec) ~= "table" then
    error(("toggle %s must be a table"):format(id), 3)
  end
  if spec.default == nil then
    error(("toggle %s must define default"):format(id), 3)
  end
  if spec.set ~= nil and type(spec.set) ~= "function" then
    error(("toggle %s set must be a function"):format(id), 3)
  end
  if spec.get ~= nil and type(spec.get) ~= "function" then
    error(("toggle %s get must be a function"):format(id), 3)
  end
end

function M.load()
  state = decode_state(read_file(config.path))
  return copy(state)
end

function M.save()
  write_file(config.path, encode_state())
end

function M.register(id, spec)
  assert_id(id)
  validate_spec(id, spec)
  registry[id] = vim.tbl_deep_extend("force", {}, spec)
  return M
end

function M.unregister(id)
  assert_id(id)
  registry[id] = nil
  state.values[id] = nil
  M.save()
  return M
end

function M.has(id)
  return registry[id] ~= nil
end

function M.get(id)
  assert_id(id)
  local toggle = assert_toggle(id)
  if state.values[id] ~= nil then
    return state.values[id]
  end
  return toggle.default
end

function M.current(id)
  assert_id(id)
  local toggle = assert_toggle(id)
  if toggle.get then
    return toggle.get()
  end
  return M.get(id)
end

function M.set(id, value)
  assert_id(id)
  local toggle = assert_toggle(id)
  state.values[id] = value
  M.save()
  if toggle.set then
    toggle.set(value)
  end
  notify(("%s %s"):format(id, tostring(value)))
  return value
end

function M.toggle(id)
  local current = M.current(id)
  if type(current) ~= "boolean" then
    error(("toggle %s current value is not boolean"):format(id), 2)
  end
  return M.set(id, not current)
end

function M.reset(id)
  assert_id(id)
  local toggle = assert_toggle(id)
  state.values[id] = nil
  M.save()
  if toggle.set then
    toggle.set(toggle.default)
  end
  notify(("%s reset"):format(id))
  return toggle.default
end

function M.reset_all()
  state.values = {}
  M.save()
  M.apply_all()
end

function M.apply(id)
  assert_id(id)
  local toggle = assert_toggle(id)
  local value = M.get(id)
  if toggle.set then
    toggle.set(value)
  end
  return value
end

function M.apply_all()
  for id, _ in pairs(registry) do
    M.apply(id)
  end
end

function M.values()
  local values = {}
  for id, toggle in pairs(registry) do
    values[id] = state.values[id] ~= nil and state.values[id] or toggle.default
  end
  return values
end

function M.persisted()
  return copy(state.values)
end

function M.defaults()
  local defaults = {}
  for id, toggle in pairs(registry) do
    defaults[id] = toggle.default
  end
  return defaults
end

function M.registry()
  return copy(registry)
end

function M.path()
  return config.path
end

local function parse_value(value)
  if value == "true" then
    return true
  end
  if value == "false" then
    return false
  end
  if value == "nil" then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, value)
  if ok then
    return decoded
  end
  return value
end

local function sorted_ids()
  local ids = vim.tbl_keys(registry)
  table.sort(ids)
  return ids
end

function M.info()
  local lines = {
    "persist-toggle.nvim",
    "path: " .. config.path,
    "",
  }

  for _, id in ipairs(sorted_ids()) do
    local toggle = registry[id]
    local persisted = state.values[id]
    local effective = persisted ~= nil and persisted or toggle.default
    table.insert(
      lines,
      ("%s default=%s persisted=%s effective=%s current=%s"):format(
        id,
        vim.inspect(toggle.default),
        vim.inspect(persisted),
        vim.inspect(effective),
        vim.inspect(M.current(id))
      )
    )
  end

  return table.concat(lines, "\n")
end

local commands_created = false

local function create_commands()
  if commands_created then
    return
  end
  commands_created = true

  vim.api.nvim_create_user_command("PersistToggle", function(args)
    if #args.fargs ~= 1 then
      error("PersistToggle expects exactly one toggle id", 0)
    end
    M.toggle(args.args)
  end, {
    nargs = "+",
    complete = function()
      return sorted_ids()
    end,
  })

  vim.api.nvim_create_user_command("PersistToggleSet", function(args)
    if #args.fargs ~= 2 then
      error("PersistToggleSet expects a toggle id and value", 0)
    end
    M.set(args.fargs[1], parse_value(args.fargs[2]))
  end, {
    nargs = "+",
    complete = function(_, line)
      if vim.split(line, "%s+")[2] == nil then
        return sorted_ids()
      end
      return { "true", "false" }
    end,
  })

  vim.api.nvim_create_user_command("PersistToggleReset", function(args)
    if #args.fargs ~= 1 then
      error("PersistToggleReset expects exactly one toggle id", 0)
    end
    M.reset(args.args)
  end, {
    nargs = "+",
    complete = function()
      return sorted_ids()
    end,
  })

  vim.api.nvim_create_user_command("PersistToggleResetAll", function()
    M.reset_all()
  end, {})

  vim.api.nvim_create_user_command("PersistToggleInfo", function()
    print(M.info())
  end, {})
end

function M.setup(opts)
  opts = opts or {}
  config = vim.tbl_deep_extend("force", copy(DEFAULT_CONFIG), opts)
  config.path = normalize_path(config.path)

  registry = {}
  for id, spec in pairs(config.toggles or {}) do
    M.register(id, spec)
  end

  M.load()
  create_commands()

  if config.apply_on_setup then
    M.apply_all()
  end

  return M
end

return M
