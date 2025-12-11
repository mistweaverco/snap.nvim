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

Via [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ 'mistweaverco/snap.nvim', opts = {} },
```

> [!NOTE]
> `opts` needs to be at least an empty table `{}` and can't be completely omitted.

## Configuration

- `templateFilepath` (optional): Absolute path to a custom handlebars template file.
  See the [default template](./templates/default.hbs) for reference.
- `additional_template_data` (optional): A table of additional data to pass to your custom the handlebars template.
   Available as `data.YOURKEY` variables in the template.

```lua
{
  'mistweaverco/snap.nvim',
  opts = {
    timeout = 5000, -- Timeout for screenshot command in milliseconds
    templateFilepath = nil, -- Absolute path to a custom handlebars template file (optional)
    -- Additional data to pass to the your custom handlebars template (optional)
    additional_template_data = {
      author = "Your Name",
      website = "https://yourwebsite.com",
    },
    output_dir = "$HOME/Pictures/Screenshots", -- Directory to save screenshots
    filename_pattern = "snap.nvim_%t.png", -- e.g., "snap.nvim_%t.png" (supports %t for timestamp)
    font_settings = {
      size = 14,         -- Default font size for the screenshot
      line_height = 0.8, -- Default line height for the screenshot
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

- `:Snap` - Save a screenshot of the current file or visual selection and copy it to the clipboard as an image.
- `:Snap html` - Copy the HTML representation of the current file or visual selection to the clipboard.
