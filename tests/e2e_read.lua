local function run()
  local applied

  require("persist-toggle").setup({
    notify = false,
    path = vim.env.PERSIST_TOGGLE_E2E_PATH,
    toggles = {
      feature = {
        default = false,
        set = function(value)
          applied = value
        end,
      },
    },
  })

  if require("persist-toggle").get("feature") ~= true then
    error("expected saved feature value to be true")
  end

  if applied ~= true then
    error("expected saved feature value to be applied on fresh startup")
  end
end

local ok, err = xpcall(run, debug.traceback)
if ok then
  print("persist-toggle.nvim e2e read passed")
  vim.cmd("qa!")
else
  vim.api.nvim_err_writeln(err)
  vim.cmd("cq")
end
