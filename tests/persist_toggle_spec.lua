local function run()
  local plugin = require("persist-toggle")

  local function assert_eq(actual, expected, label)
    if not vim.deep_equal(actual, expected) then
      error(("%s\nexpected: %s\nactual: %s"):format(label or "assert_eq failed", vim.inspect(expected), vim.inspect(actual)))
    end
  end

  local function temp_path(name)
    return vim.fn.getcwd() .. "/.test-tmp/" .. name .. ".json"
  end

  vim.fn.delete(vim.fn.getcwd() .. "/.test-tmp", "rf")
  vim.fn.mkdir(vim.fn.getcwd() .. "/.test-tmp", "p")

  do
    local applied = {}
    plugin.setup({
      notify = false,
      path = temp_path("defaults"),
      toggles = {
        diagnostics = {
          default = true,
          get = function()
            return applied.diagnostics
          end,
          set = function(value)
            applied.diagnostics = value
          end,
        },
      },
    })

    assert_eq(plugin.get("diagnostics"), true, "default is returned when no state exists")
    assert_eq(applied.diagnostics, true, "default is applied on setup")
    plugin.toggle("diagnostics")
    assert_eq(plugin.get("diagnostics"), false, "toggle updates persisted value")
    assert_eq(applied.diagnostics, false, "toggle applies value")

    plugin.setup({
      notify = false,
      path = temp_path("defaults"),
      toggles = {
        diagnostics = {
          default = true,
          set = function(value)
            applied.diagnostics = value
          end,
        },
      },
    })

    assert_eq(plugin.get("diagnostics"), false, "saved state survives setup")
    assert_eq(applied.diagnostics, false, "saved state is applied on setup")
  end

  do
    local applied
    plugin.setup({
      notify = false,
      path = temp_path("reset"),
      toggles = {
        feature = {
          default = "auto",
          set = function(value)
            applied = value
          end,
        },
      },
    })

    plugin.set("feature", "manual")
    assert_eq(plugin.get("feature"), "manual", "set stores non-boolean value")
    plugin.reset("feature")
    assert_eq(plugin.get("feature"), "auto", "reset returns to default")
    assert_eq(applied, "auto", "reset applies default")
  end

  do
    local path = temp_path("invalid")
    vim.fn.writefile({ "{" }, path)
    plugin.setup({
      notify = false,
      path = path,
      toggles = {
        feature = {
          default = true,
        },
      },
    })

    assert_eq(plugin.get("feature"), true, "invalid JSON falls back to defaults")
  end

  do
    plugin.setup({
      notify = false,
      path = temp_path("commands"),
      toggles = {
        cmd_feature = {
          default = false,
        },
      },
    })

    vim.cmd("PersistToggle cmd_feature")
    assert_eq(plugin.get("cmd_feature"), true, "PersistToggle command toggles state")
    vim.cmd("PersistToggleSet cmd_feature false")
    assert_eq(plugin.get("cmd_feature"), false, "PersistToggleSet command stores parsed boolean")
    vim.cmd("PersistToggleReset cmd_feature")
    assert_eq(plugin.get("cmd_feature"), false, "PersistToggleReset command restores default")
  end

  vim.fn.delete(vim.fn.getcwd() .. "/.test-tmp", "rf")
end

local ok, err = xpcall(run, debug.traceback)
if ok then
  print("persist-toggle.nvim tests passed")
  vim.cmd("qa!")
else
  vim.api.nvim_err_writeln(err)
  vim.cmd("cq")
end
