# Integration Examples

These snippets are starting points. Keep the `id`, `default`, `get`, and `set`
logic close to the plugin API you already use in your config.

## Core Options

```lua
{
  "javanoo6/persist-toggle.nvim",
  opts = {
    toggles = {
      number = {
        default = true,
        get = function()
          return vim.wo.number
        end,
        set = function(value)
          vim.wo.number = value
        end,
      },
      relativenumber = {
        default = true,
        get = function()
          return vim.wo.relativenumber
        end,
        set = function(value)
          vim.wo.relativenumber = value
        end,
      },
      wrap = {
        default = false,
        get = function()
          return vim.wo.wrap
        end,
        set = function(value)
          vim.wo.wrap = value
        end,
      },
      spell = {
        default = false,
        get = function()
          return vim.wo.spell
        end,
        set = function(value)
          vim.wo.spell = value
        end,
      },
      mouse = {
        default = false,
        get = function()
          return vim.o.mouse ~= ""
        end,
        set = function(value)
          vim.o.mouse = value and "a" or ""
        end,
      },
    },
  },
}
```

## Diagnostics

```lua
require("persist-toggle").register("diagnostics", {
  default = true,
  get = function()
    return vim.diagnostic.is_enabled()
  end,
  set = function(value)
    vim.diagnostic.enable(value)
  end,
})
```

## Inlay Hints

```lua
require("persist-toggle").register("inlay_hints", {
  default = true,
  get = function()
    return vim.lsp.inlay_hint.is_enabled()
  end,
  set = function(value)
    vim.lsp.inlay_hint.enable(value)
  end,
})
```

For configs that keep their own global inlay-hint preference:

```lua
require("persist-toggle").register("inlay_hints", {
  default = true,
  get = function()
    return vim.g.inlay_hints_enabled ~= false
  end,
  set = function(value)
    vim.g.inlay_hints_enabled = value
    vim.lsp.inlay_hint.enable(value)
  end,
})
```

## tiny-inline-diagnostic.nvim

`tiny-inline-diagnostic.nvim` exposes a toggle command. If you also keep a
global preference, make that preference the source of truth.

```lua
require("persist-toggle").register("tiny_inline_diagnostic", {
  default = true,
  get = function()
    return vim.g.tiny_inline_diagnostic_enabled ~= false
  end,
  set = function(value)
    vim.g.tiny_inline_diagnostic_enabled = value

    local ok, tid = pcall(require, "tiny-inline-diagnostic")
    if ok then
      if value then
        tid.enable()
      else
        tid.disable()
      end
    end
  end,
})
```

If your installed version only exposes `toggle()`, wrap it with tracked state:

```lua
local tiny_inline_enabled = true

require("persist-toggle").register("tiny_inline_diagnostic", {
  default = true,
  get = function()
    return tiny_inline_enabled
  end,
  set = function(value)
    if tiny_inline_enabled == value then
      return
    end

    tiny_inline_enabled = value
    require("tiny-inline-diagnostic").toggle()
  end,
})
```

## gitsigns.nvim

These `gitsigns.nvim` display toggles accept an explicit boolean value, but they
do not expose separate getters. Track the intended value locally and set the
display state directly.

```lua
local function gitsigns_toggle(default, fn)
  local current = default

  return {
    default = default,
    get = function()
      return current
    end,
    set = function(value)
      current = value
      local ok, gs = pcall(require, "gitsigns")
      if ok then
        gs[fn](value)
      end
    end,
  }
end

require("persist-toggle").setup({
  toggles = {
    gitsigns_current_line_blame = gitsigns_toggle(false, "toggle_current_line_blame"),
    gitsigns_word_diff = gitsigns_toggle(false, "toggle_word_diff"),
    gitsigns_linehl = gitsigns_toggle(false, "toggle_linehl"),
    gitsigns_deleted = gitsigns_toggle(false, "toggle_deleted"),
  },
})
```

## auto-save.nvim

Register this after `auto-save.nvim` has been set up, or make
`persist-toggle.nvim` load after it.

```lua
require("persist-toggle").register("auto_save", {
  default = true,
  get = function()
    local ok, auto_save = pcall(require, "auto-save")
    return ok and auto_save.enabled()
  end,
  set = function(value)
    local ok, auto_save = pcall(require, "auto-save")
    if ok then
      if value then
        auto_save.on()
      else
        auto_save.off()
      end
    end
  end,
})
```

If your version only exposes `:ASToggle`, prefer tracking the state yourself and
using `vim.cmd.ASToggle()` only when the desired state differs from the tracked
state.

## conform.nvim Format-on-Save Preference

Many configs control format-on-save with a global variable. Persist that
preference and let your existing formatting autocmd keep using the variable.

```lua
require("persist-toggle").register("format_on_save", {
  default = true,
  get = function()
    return vim.g.disable_autoformat ~= true
  end,
  set = function(value)
    vim.g.disable_autoformat = not value
  end,
})
```

## Neo-tree Reveal Preference

Persist a preference used by your own Neo-tree wrapper:

```lua
require("persist-toggle").register("neotree_reveal_on_open", {
  default = true,
  get = function()
    return vim.g.neotree_reveal_on_open ~= false
  end,
  set = function(value)
    vim.g.neotree_reveal_on_open = value
  end,
})
```

## DAP UI Keep Open

This persists a preference variable used by DAP listeners.

```lua
require("persist-toggle").register("dapui_keep_open_on_exit", {
  default = false,
  get = function()
    return vim.g.dapui_keep_open_on_exit == true
  end,
  set = function(value)
    vim.g.dapui_keep_open_on_exit = value
  end,
})
```

## snacks.nvim Toggle Interop

`snacks.nvim` already provides a toggle abstraction. You can use
`persist-toggle.nvim` as the durable store and expose the same action through
Snacks.

```lua
require("persist-toggle").register("diagnostics", {
  default = true,
  get = function()
    return vim.diagnostic.is_enabled()
  end,
  set = function(value)
    vim.diagnostic.enable(value)
  end,
})

Snacks.toggle({
  id = "diagnostics",
  name = "Diagnostics",
  get = function()
    return require("persist-toggle").current("diagnostics")
  end,
  set = function(value)
    require("persist-toggle").set("diagnostics", value)
  end,
}):map("<leader>ud")
```

## Buffer-Local Toggles

For buffer-local state, include the buffer identity in your toggle id or keep it
non-persistent. Most users expect runtime preferences to survive restarts, while
temporary per-buffer debug switches usually should not.

```lua
local function buffer_toggle_id(name, bufnr)
  return ("%s:%s"):format(name, vim.api.nvim_buf_get_name(bufnr))
end

local id = buffer_toggle_id("treesitter_disabled", 0)

require("persist-toggle").register(id, {
  default = false,
  get = function()
    return vim.b.treesitter_disabled == true
  end,
  set = function(value)
    vim.b.treesitter_disabled = value
  end,
})
```
