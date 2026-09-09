# persist-toggle.nvim

Persistent toggle state registry for Neovim.

Register toggles once, restore user preferences across restarts, and keep
plugin-specific state wiring out of your keymaps.

## Why

Session plugins restore editing sessions: buffers, windows, folds, terminals,
and other `:mksession` state. They are not a durable preference layer for
runtime toggles like diagnostics, inlay hints, auto-save, line numbers, plugin
visibility, or custom UI behavior.

`persist-toggle.nvim` gives those preferences a small explicit registry.

## Installation

With `lazy.nvim`:

```lua
{
  "javanoo6/persist-toggle.nvim",
  opts = {
    toggles = {
      diagnostics = {
        default = true,
        get = function()
          return vim.diagnostic.is_enabled()
        end,
        set = function(value)
          vim.diagnostic.enable(value)
        end,
      },
      inlay_hints = {
        default = true,
        get = function()
          return vim.lsp.inlay_hint.is_enabled()
        end,
        set = function(value)
          vim.lsp.inlay_hint.enable(value)
        end,
      },
    },
  },
}
```

## Usage

```lua
local toggles = require("persist-toggle")

toggles.toggle("diagnostics")
toggles.set("inlay_hints", false)
toggles.get("diagnostics")
toggles.current("diagnostics")
toggles.reset("diagnostics")
toggles.reset_all()
```

The saved state is stored as JSON at:

```lua
vim.fn.stdpath("state") .. "/persist-toggle/state.json"
```

Override it with:

```lua
require("persist-toggle").setup({
  path = vim.fn.stdpath("state") .. "/my-toggle-state.json",
})
```

## Commands

```vim
:PersistToggle diagnostics
:PersistToggleSet diagnostics true
:PersistToggleReset diagnostics
:PersistToggleResetAll
:PersistToggleInfo
```

## Keymaps

```lua
vim.keymap.set("n", "<leader>ud", function()
  require("persist-toggle").toggle("diagnostics")
end, { desc = "Toggle diagnostics" })
```

## Examples

See [integration examples](docs/integrations.md) for snippets covering core
options, diagnostics, inlay hints, `tiny-inline-diagnostic.nvim`,
`gitsigns.nvim`, `auto-save.nvim`, Neo-tree preferences, DAP UI preferences,
and `snacks.nvim` interop.

## API

```lua
require("persist-toggle").setup({
  path = vim.fn.stdpath("state") .. "/persist-toggle/state.json",
  notify = true,
  apply_on_setup = true,
  toggles = {
    name = {
      default = true,
      get = function()
        return true
      end,
      set = function(value)
      end,
    },
  },
})
```

- `register(id, spec)`: add a toggle after setup.
- `unregister(id)`: remove a toggle and its saved value.
- `has(id)`: check if a toggle is registered.
- `get(id)`: return saved value, or the default.
- `current(id)`: read live state through `spec.get`, falling back to `get`.
- `set(id, value)`: save and apply a value.
- `toggle(id)`: flip a boolean live value and save it.
- `reset(id)`: remove saved override and apply the default.
- `reset_all()`: remove all saved overrides and apply all defaults.
- `apply(id)`: apply the saved/default value.
- `apply_all()`: apply every registered toggle.
- `values()`: return effective values for registered toggles.
- `persisted()`: return only saved overrides.
- `defaults()`: return registered defaults.
- `registry()`: return registered specs.
- `path()`: return the configured state file path.
- `info()`: return a printable state report.

## Design

The plugin deliberately does not introspect arbitrary plugins. Neovim plugins
store runtime state in many different ways, so each toggle declares how to read
and write its own state.

That keeps persistence predictable and makes integration failures visible in
your config instead of hidden in plugin magic.

## Tests

```sh
make test
```

The tests run inside headless Neovim and verify persistence, startup restore,
reset behavior, invalid JSON handling, user commands, and a two-process e2e
restart flow.
