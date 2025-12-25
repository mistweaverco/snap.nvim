<div align="center">

![Snap.nvim Logo][logo]

# Snap.nvim

[![Made with love][badge-made-with-love]][contributors]
![Made with lua][badge-made-with-lua]
[![Latest release][badge-latest-release]][latest-release]

[What](#what) •
[Requirements](#requirements) •
[Install](#install) •
[Configuration](#configuration)

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
- Extraction tools for archive extraction:
  - **Windows**: `unzip` (usually available via Git Bash, WSL, or MSYS2)
  - **Linux/macOS**: `tar` (typically pre-installed)
- linux-amd64, macos-amd64, macos-arm64 or windows-amd64 system
  (you need to build from source for other systems)

### Linux dependencies

On Linux systems, the following packages are required for the bundled Chromium browser:

```bash
# Debian/Ubuntu
sudo apt install libnss3 libatk-bridge2.0-0 libx11-xcb1

# Fedora/RHEL
sudo dnf install nss atk at-spi2-atk libxkbcommon

# Arch Linux
sudo pacman -S nss atk at-spi2-atk libxkbcommon
```

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
  version = 'v1.4.1',
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
  tag = 'v1.4.1',
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
  version = 'v1.4.1',
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

See the [builtin templates](./templates/) for reference.

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
  version = 'v1.4.1',
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
- `%time` - Time in `HHMMSS` format, e.g., `153045`
- `%date` - Date in `YYYYMMDD` format, e.g., `20210702`
- `%file_name` - Original filename, e.g., `my_script`
- `%file_extension` - Original file extension, e.g., `lua`, `py`, `js`
- `%unixtime` - Unix timestamp, e.g., `1625247600`

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

### Configure `log_level`

Optional. Defaults to `"error"`.

Log level for debugging. Controls which log messages are displayed.

Valid options are:

- `"trace"` - Most verbose, shows all log messages
- `"debug"` - Shows debug, info, warn, and error messages
- `"info"` - Shows info, warn, and error messages
- `"warn"` - Shows warn and error messages
- `"error"` - Shows only error messages (default)
- `"off"` - Disables all logging

```lua
log_level = "error",  -- Log level for debugging
```

### Configure `development_mode`

Optional. Defaults to `nil`.

If set, no pre-compiled binaries will be downloaded
and the plugin will attempt to run directly from source.

Requires [Bun](https://bun.sh/) to be installed on your system.
Additionally you need to install the dependencies
by running `bun install` in the plugin directory.

```lua
{
  backend = "bun",  -- Development mode backend to use (currently only "bun" is supported)
}
```

### Full example configuration

```lua
{
  'mistweaverco/snap.nvim',
  version = 'v1.4.1',
  opts = {
    timeout = 5000, -- Timeout for screenshot command in milliseconds
    log_level = "error", -- Log level for debugging (e.g., "trace", "debug", "info", "warn", "error", "off")
    template = "default", -- Template to use for rendering screenshots ("default", "macos", "linux")
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
    -- defaults to nil
    -- if set, no pre-compiled binaries will be downloaded
    -- and the plugin will attempt to run directly from source
    development_mode = {
      backend = "bun",  -- Development mode backend to use (currently only "bun" is supported)
    },
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

[badge-made-with-lua]: assets/badge-made-with-lua.svg
[badge-made-with-love]: assets/badge-made-with-love.svg
[contributors]: https://github.com/mistweaverco/snap.nvim/graphs/contributors
[logo]: assets/logo.svg
[badge-latest-release]: https://img.shields.io/github/v/release/mistweaverco/snap.nvim?style=for-the-badge
[latest-release]: https://github.com/mistweaverco/snap.nvim/releases/latest
