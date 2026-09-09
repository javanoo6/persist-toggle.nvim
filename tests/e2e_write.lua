local function run()
  local applied

  require("persist-toggle").setup({
    notify = false,
    path = vim.env.PERSIST_TOGGLE_E2E_PATH,
    toggles = {
      feature = {
        default = false,
        get = function()
          return applied
        end,
        set = function(value)
          applied = value
        end,
      },
    },
  })

  require("persist-toggle").toggle("feature")

  if applied ~= true then
    error("expected feature to be applied as true")
  end
end

local ok, err = xpcall(run, debug.traceback)
if ok then
  print("persist-toggle.nvim e2e write passed")
  vim.cmd("qa!")
else
  vim.api.nvim_err_writeln(err)
  vim.cmd("cq")
end
