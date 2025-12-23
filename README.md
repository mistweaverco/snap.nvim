<div align="center">

![Snap.nvim Logo](assets/logo.svg)

# Snap.nvim

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/mistweaverco/snap.nvim?style=for-the-badge)](https://github.com/mistweaverco/snap.nvim/releases/latest)

[What](#what) • [Requirements](#requirements) • [Install](#install) • [Configuration](#configuration)

<p></p>

A minimal screenshot plugin for Neovim.

It respects your current color scheme to ensure that the screenshots
blend seamlessly with your Neovim setup.

</div>

## What

Snap.nvim is a minimal screenshot plugin for Neovim that
allows users to capture screenshots directly from the editor.

It provides a uncomplicated and efficient way to take screenshots without
leaving the Neovim environment.

Just select the area you want to capture in visual mode and
run the command to take a screenshot.

Or you can run the command without selecting anything to
capture the entire Neovim window.

## Requirements

- Neovim 0.11.5+
- cURL installed on your system
  (for downloading pre-built binaries)
- linux-amd64, macos-amd64, macos-arm64 or windows-amd64 system
  (you need to build from source for other systems)

## Install

Please use release tags when installing the plugin to ensure
compatibility and stability.

The `main` branch may contain breaking changes
and isn't guaranteed to be stable.

### lazy.nvim

See: [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'mistweaverco/snap.nvim',
  version = 'v1.2.0',
  ---@type SnapUserConfig
  opts = {}
},
```

> [!IMPORTANT]
> `opts` needs to be at least an empty table `{}` and can't be completely omitted.

### packer.nvim

See: [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'mistweaverco/snap.nvim',
  tag = 'v1.2.0',
  config = function()

    ---@type SnapUserConfig
    local cfg = {}
    require('snap').setup(cfg)
  end
})
```

> [!IMPORTANT]
> `setup` call needs to have at least an empty table `{}` and
> can't be completely omitted.

### Neovim built-in package manager

```lua
vim.pack.add({
  src = 'https://github.com/mistweaverco/snap.nvim.git',
  version = 'v1.2.0',
})
---@type SnapUserConfig
local cfg = {}
require('snap').setup(cfg)
```

> [!IMPORTANT]
> `setup` call needs to have at least an empty table `{}` and
> can't be completely omitted.

## Configuration

### Configure `templateFilepath`

Optional. Defaults to `nil`.

Absolute path to a custom handlebars template file.

See the [default template](./templates/default.hbs) for reference.

### Configure `additional_template_data`

Optional. Defaults to `{}`.

A table of additional data to pass to your custom the handlebars template.

Available as `data.YOURKEY` variables in the template.

### Configure `font_settings`

Optional. Defaults to:

```lua
{
  size = 14, -- Default font size for the screenshot in pt
  line_height = 1.0, -- Default line height for the screenshot in pt
  default = {
    name = "FiraCode Nerd Font",
    file = nil,
  },
  bold = {
    name = "FiraCode Nerd Font",
    file = nil,
  },
  italic = {
    name = "FiraCode Nerd Font",
    file = nil,
  },
  bold_italic = {
    name = "FiraCode Nerd Font",
    file = nil,
  },
}
```

Configure font settings for the screenshot.

Font settings are optional,
but recommended to ensure that the screenshot
matches your Neovim setup.

We can't detect your font settings (of your terminal) automatically,
so you need to specify them manually.

For wezterm, this is what it could look like in your wezterm config:

```lua
local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.font = wezterm.font_with_fallback({
  "FiraCode Nerd Font",
  "VictorMono Nerd Font",
  "Noto Color Emoji",
})

config.font_rules = {
  {
    italic = true,
    intensity = "Normal",
    font = wezterm.font({
      family = "VictorMono Nerd Font",
      stretch = "Normal",
      weight = "Regular",
      style = "Italic",
    }),
  },
  {
    italic = true,
    intensity = "Bold",
    font = wezterm.font({
      family = "VictorMono Nerd Font",
      stretch = "Normal",
      weight = "Bold",
      style = "Italic",
    }),
  },
  {
    italic = false,
    intensity = "Normal",
    font = wezterm.font({
      family = "FiraCode Nerd Font",
      stretch = "Normal",
      weight = "Regular",
      style = "Normal",
    }),
  },
  {
    italic = false,
    intensity = "Bold",
    font = wezterm.font({
      family = "FiraCode Nerd Font",
      stretch = "Normal",
      weight = "Bold",
      style = "Normal",
    }),
  },
}

config.font_size = 14.0
config.line_height = 1.0

return config
```

This would then translate to the following `font_settings`:

```lua
return {
  "mistweaverco/snap.nvim",
  version = "v1.2.0",
  ---@type SnapUserConfig
  opts = {
    template = "linux",
    font_settings = {
      size = 14,
      line_height = 1.0,
      fonts = {
        default = {
          name = "FiraCode Nerd Font",
          file = nil,
        },
        bold = {
          name = "VictorMono Nerd Font",
          file = nil,
        },
        italic = {
          name = "VictorMono Nerd Font",
          file = nil,
        },
        bold_italic = {
          name = "VictorMono Nerd Font",
          file = nil,
        },
      },
    },
  },
}
```

### Configure `timeout`

Optional. Defaults to `5000`.

Timeout for the screenshot command in milliseconds.

### Configure `output_dir`

Optional. Defaults to `$HOME/Pictures/Screenshots`.

Directory to save screenshots.

### Configure `filename_pattern`

Optional. Defaults to `snap.nvim_%t`.

Filename pattern for the generated files.
File extension will be added automatically based on the output format.

Supports the following placeholders:

- `%t` - Timestamp in `YYYYMMDD_HHMMSS` format

### Configure `template`

Optional. Defaults to `default`.

Template to use for rendering screenshots.

Valid options are:

- `default` - The default template provided by the plugin
- `macos` - A macOS-style template
- `linux` - A Linux-style template

### Configure `template_filepath`

Optional. Defaults to `nil`.

Absolute path to a custom handlebars template file.
If set, this option overrides the `template` option.

### Configure `copy_to_clipboard`

Optional. Defaults to:

```lua
{
  image = true,
  html = true,
}
```

### Configure `debug`

Optional. Defaults to `nil`.

If set, no pre-compiled binaries will be downloaded
and the plugin will attempt to run directly from source.

Requires [Bun](https://bun.sh/) to be installed on your system.
Additionally you need to install the dependencies
by running `bun install` in the plugin directory.

```lua
{
  backend = "bun",         -- Debug backend to use (currently only "bun" is supported)
  log_level = "info",      -- Log level for debugging (e.g., "info", "debug", "error")
}
```

### Full example configuration

```lua
{
  'mistweaverco/snap.nvim',
  version = 'v1.2.0',
  opts = {
    timeout = 5000, -- Timeout for screenshot command in milliseconds
    template = "default", -- Template to use for rendering screenshots (currently only "default" is supported)
    template_filepath = nil, -- Absolute path to a custom handlebars template file (optional), overrides 'template' option
    -- Additional data to pass to the your custom handlebars template (optional)
    additional_template_data = {
      author = "Your Name",
      website = "https://yourwebsite.com",
    },
    output_dir = "$HOME/Pictures/Screenshots", -- Directory to save screenshots
    filename_pattern = "snap.nvim_%t", -- e.g., "snap.nvim_%t" (supports %t for timestamp)
    copy_to_clipboard = {
        image = true, -- Whether to copy the image to clipboard
        html = true, -- Whether to copy the HTML to clipboard
    },
    font_settings = {
      size = 14,         -- Default font size for the screenshot in pt
      line_height = 1.0, -- Default line height for the screenshot in pt
      default = {
        name = "FiraCode Nerd Font", -- Default font name for the screenshot
        file = nil,         -- Absolute path to a custom font file (.ttf) (optional)
        -- Only needed if the font is not installed system-wide
        -- or if you want to export as HTML with the font embedded
        -- so you can view it correctly in E-mails or browsers
      },
      -- Optional font settings for different text styles (bold, italic, bold_italic)
      bold = {
        name = "FiraCode Nerd Font", -- Font name for bold text
        file = nil,         -- Absolute path to a custom font file (.ttf) (optional)
        -- Only needed if the font is not installed system-wide
        -- or if you want to export as HTML with the font embedded
        -- so you can view it correctly in E-mails or browsers
      },
      italic = {
        name = "FiraCode Nerd Font", -- Font name for italic text
        file = nil,         -- Absolute path to a custom font file (.ttf) (optional)
        -- Only needed if the font is not installed system-wide
        -- or if you want to export as HTML with the font embedded
        -- so you can view it correctly in E-mails or browsers
      },
      bold_italic = {
        name = "FiraCode Nerd Font", -- Font name for bold and italic text
        file = nil,         -- Absolute path to a custom font file (.ttf) (optional)
        -- Only needed if the font is not installed system-wide
        -- or if you want to export as HTML with the font embedded
        -- so you can view it correctly in E-mails or browsers
      },
    },
  },
  -- defaults to nil
  -- if set, no pre-compiled binaries will be downloaded
  -- and the plugin will attempt to run directly from source
  debug = {
    backend = "bun",         -- Debug backend to use (currently only "bun" is supported)
    log_level = "info",      -- Log level for debugging (e.g., "info", "debug", "error")
  },
},
```


## Commands

All commands can be run in normal or visual mode.

> [!IMPORTANT]
> Clipboard functionality depends on your system's clipboard
> and Neovim's clipboard support being properly configured.
>
> For Linux systems, ensure that you have
> `wl-clip` or `xclip` installed for clipboard operations to work.
>
> On macOS, clipboard support is typically available by default.
>
> On Windows, clipboard support is also generally available by default.

### Snap command

Usage: `:Snap`

Save a screenshot of the current file or
visual selection and copy it to the clipboard as an image.

## Snap arguments

Usage: `:Snap args`

Snap allows different arguments to control its behavior.

### Snap html argument

Usage: `:Snap html`

Save a screenshot of the current file or visual selection as an HTML file and
copy the HTML representation to the clipboard.
