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

Choose one installation method. The examples use Neovim 0.10+ APIs.
No other plugins are required.

### lazy.nvim / LazyVim

If your config imports `lua/plugins/` (including LazyVim), create
`lua/plugins/persist-toggle.lua` with the following. Otherwise, add the inner
plugin spec to your existing `require("lazy").setup({ ... })` list.

```lua
return {
  "javanoo6/persist-toggle.nvim",
  lazy = false, -- Restore preferences at startup.
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

Run `:Lazy sync` and restart Neovim. `opts` calls `setup()` automatically.
Use the plugin's commands or API to change toggles so their values are saved;
changes made directly through other plugins are not automatically tracked.

### Local development with lazy.nvim

To try changes from a local checkout, use the same spec above and add `dir`:

```lua
dir = vim.fn.expand("~/src/persist-toggle.nvim"),
```

Replace the path with your checkout's location. Keep `lazy = false` and the
`opts` table from the full example. lazy.nvim supports local plugins through
[`dir`](https://lazy.folke.io/spec); a Git submodule is not required.

### vim-plug

Add this line between your existing `plug#begin()` and `plug#end()` calls:

```vim
Plug 'javanoo6/persist-toggle.nvim'
```

Run `:PlugInstall`, restart Neovim, then add the [manual setup](#manual-setup)
below after `plug#end()`. See [vim-plug](https://github.com/junegunn/vim-plug)
for plugin manager setup instructions.

### Native Neovim package

Without a plugin manager, clone into Neovim's package directory. For the
default Linux/macOS config location:

```sh
git clone https://github.com/javanoo6/persist-toggle.nvim.git \
  "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/pack/plugins/start/persist-toggle.nvim"
```

Add the [manual setup](#manual-setup) below to `init.lua`, then restart Neovim.
For custom config locations, use `:echo stdpath('config')` to find the base
directory. See Neovim's [package documentation](https://neovim.io/doc/user/pack.html).

### Git submodule in your config repository

This is optional: use it when you want your config repository to track the
plugin checkout and its exact commit. With lazy.nvim, the normal GitHub spec
and `lazy-lock.json` are usually sufficient.

From the root of your Git-managed Neovim config, run:

```sh
git submodule add https://github.com/javanoo6/persist-toggle.nvim.git \
  pack/plugins/start/persist-toggle.nvim
```

Commit `.gitmodules` and the submodule entry with your config changes. On
another machine, clone your config with `git clone --recurse-submodules`, or
run `git submodule update --init --recursive` in an existing clone.

This uses native package loading, so add the [manual setup](#manual-setup)
below. Choose either this method or the lazy.nvim spec to avoid duplicate
installations.

### Manual setup

For vim-plug, native packages, and the submodule method, add this to `init.lua`
after your plugin manager setup, if any. For `init.vim`, wrap the Lua code in
`lua << EOF` and `EOF` lines.

```lua
require("persist-toggle").setup({
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
  },
})
```

Setup restores registered preferences immediately. For toggles that call
another plugin, ensure that plugin is initialized before applying its state;
see the [integration examples](docs/integrations.md).

### Verify the installation

Run `:PersistToggleInfo` to see the registered toggles and state file path.
Run `:PersistToggle diagnostics`, restart Neovim, and check that diagnostics
keep the value you selected. An empty `setup({})` creates the commands but
registers no toggles.

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
