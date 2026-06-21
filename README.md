# Wallpaper Setter Bypass (WSB)

<img src="https://img.shields.io/badge/Target-Windows-green?style=flat" alt="Target Hardware"/> &nbsp; <img src="https://img.shields.io/github/v/release/Oignontom8283/Wallpaper-Setter-Bypass?include_prereleases&style=flat&logo=github" alt="Version"/>

[Français](README_FR.md) | **English**

A PowerShell application that bypasses the native Windows wallpaper settings to apply wallpapers directly with advanced scaling, styling, and background color options. Works without administrator privileges.

![Illustration of WSB GUI](./assets/gui.png)

![Demo GIF Animation](./assets/demo.gif)


## Features

- [x] **Triple Method Support**: Choose between the COM interface (IDesktopWallpaper), the classic Win32 API (SPI), or direct registry manipulation
- [x] **GUI Mode**: Interactive graphical interface for easy wallpaper selection
- [x] **CLI Mode**: Command-line interface for automation and scripting
- [x] **Image Validation**: Automatic validation to detect corrupted or invalid image files
- [x] **Display Modes**: Center, Tile, Stretch, Fit, Fill, Span (depending on the chosen method)
- [x] **Background Color**: Select and live-preview the desktop background color shown behind the wallpaper (COM method only)
- [x] **Multi-Monitor Support**: Apply wallpapers to a specific monitor, all monitors, or span a single image across all screens (COM method)
- [x] **Image Preview**: Live 16:9 preview of the selected image before applying
- [x] **No Admin Required**: Works without administrator privileges
- [x] **Method Reference**: Built-in info button explaining each method in detail and its use cases

## Supported Image Formats

- JPG / JPEG
- PNG
- BMP
- GIF
- TIFF / TIF

## Requirements

- Windows 7 or later
- PowerShell 5.1 or later
- No special privileges required

## Usage

### GUI Mode (Interactive)

Simply run the launcher batch file:

```cmd
launcher.bat
```

Or run the PowerShell script directly:

```powershell
.\wallpaper_setter.ps1
```

This opens a window where you can:

1. Click **`Browse…`** to select an image file
2. View the 16:9 image preview on the right side
3. Choose the **method** to use:
   - **COM** *(recommended)*: Modern method via the Windows Shell interface, with per-monitor support, advanced position styles, and background color control
   - **SPI**: Classic Win32 API, applies globally to all monitors, rarely blocked in managed environments
   - **Registry**: Direct registry write, last resort if both COM and SPI fail
4. Configure the **options** for the chosen method (see details below)
5. *(COM method only)* Change the **background color** via the `Change…` button — visible behind the wallpaper when it doesn't fill the entire screen
6. Click **`Apply`** to set the wallpaper
7. Click **`Exit`** to close without applying
8. Click **`i`** to open the built-in method reference

#### Options per method

**COM** — `IDesktopWallpaper` (default)

| Option | Values | Description |
|---|---|---|
| Monitor | `current`, `primary`, `all`, numeric index | Target monitor. `current` = monitor under the cursor |
| Position | `Center`, `Tile`, `Stretch`, `Fit`, `Fill`, `Span` | Display style |
| Background color | `Black`, `White`, `Gray`, `Dark Gray`, `Navy`, `Dark Green`, `Maroon`, `Custom…` | Color shown behind the image |

**SPI** — `SystemParametersInfo`

| Option | Values | Description |
|---|---|---|
| Display mode | `fullscreen`, `tile` | Global display style |
| Stretch to fill | checkbox | Stretch the image to fill the screen (fullscreen mode only) |
| Span across all monitors | checkbox | Treat all monitors as a single wide canvas |

**Registry** — Direct write

| Option | Values | Description |
|---|---|---|
| Display mode | `fullscreen`, `tile` | Display style (fullscreen = WallpaperStyle 6, tile = WallpaperStyle 1) |

### CLI Mode (Command Line)

```powershell
.\wallpaper_setter.ps1 -Path "C:\path\to\image.jpg" [Options]
```

#### Common options

| Option | Description |
|---|---|
| `-Path <path>` | Full path to the image file *(required for CLI mode)* |
| `-Method <method>` | Method: `COM` (default), `SPI`, `Registry` |
| `-Help` | Display help message |

#### COM options

| Option | Description |
|---|---|
| `-Monitor <value>` | `primary` (default), `all`, `current`, or numeric index (`0`, `1`, `2`…) |
| `-Position <value>` | `Center`, `Tile`, `Stretch`, `Fit`, `Fill` (default), `Span` |
| `-BgColor <value>` | `Black` (default), `White`, `Gray`, `Dark Gray`, `Navy`, `Dark Green`, `Maroon` |

#### SPI options

| Option | Description |
|---|---|
| `-DisplayMode <mode>` | `fullscreen` (default) or `tile` |
| `-Stretch` | Stretch the image to fill the screen (fullscreen only) |
| `-Spanned` | Span across all monitors |

#### Registry options

| Option | Description |
|---|---|
| `-DisplayMode <mode>` | `fullscreen` (default) or `tile` |

#### Examples

Apply on the current monitor (COM, Fill):
```powershell
.\wallpaper_setter.ps1 -Path "C:\images\wallpaper.jpg"
```

Apply on the primary monitor with Fit position:
```powershell
.\wallpaper_setter.ps1 -Path "C:\images\wallpaper.jpg" -Method COM -Monitor primary -Position Fit
```

Apply on monitor 1 with a navy background:
```powershell
.\wallpaper_setter.ps1 -Path "C:\images\wallpaper.jpg" -Method COM -Monitor 1 -BgColor Navy
```

Span across all monitors:
```powershell
.\wallpaper_setter.ps1 -Path "C:\images\wallpaper.jpg" -Method COM -Position Span
```

Apply via SPI in tile mode:
```powershell
.\wallpaper_setter.ps1 -Path "C:\images\wallpaper.jpg" -Method SPI -DisplayMode tile
```

Apply via SPI spanned across all monitors:
```powershell
.\wallpaper_setter.ps1 -Path "C:\images\wallpaper.jpg" -Method SPI -Spanned
```

Apply via the Registry method:
```powershell
.\wallpaper_setter.ps1 -Path "C:\images\wallpaper.jpg" -Method Registry
```

Display help:
```powershell
.\wallpaper_setter.ps1 -Help
```

## How It Works

WSB bypasses the standard Windows Settings GUI by directly modifying wallpaper configuration through three independent methods:

**COM method** — The most feature-rich. Uses the `IDesktopWallpaper` COM interface exposed by the Windows Shell. Enables per-monitor addressing (via device path), six position styles, and desktop background color control. This is the native approach on Windows 8 and later, but it is frequently blocked by Group Policy in managed environments (corporate networks, schools, kiosk setups).

**SPI method** — Uses the classic Win32 `SystemParametersInfo` call (`SPI_SETDESKWALLPAPER`). First writes the desired style to the registry (`HKCU\Control Panel\Desktop`), then triggers the update via the API. Global application only — all monitors receive the same image. Rarely blocked, making it the best fallback when COM is unavailable.

**Registry method** — Writes `Wallpaper`, `WallpaperStyle`, and `TileWallpaper` values directly into `HKCU\Control Panel\Desktop`, then forces a desktop refresh. Limited feature set (fullscreen or tile only, no per-monitor support). Use as a last resort.

In all cases, the change is applied immediately — no restart or logoff required.

## Troubleshooting

### PowerShell execution policy error?

Use the launcher batch file:
```cmd
launcher.bat
```
Or enable script execution for the current user:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
```

### Image not applying?

- Check that the image file path is correct and that the format is supported
- If COM fails (restricted environment), try the SPI method
- If SPI also fails, try the Registry method
- Check the console for detailed error messages

### Background color not applying?

Background color is a COM-exclusive feature. It is not available with SPI or Registry. If COM is blocked in your environment, the background color cannot be changed through WSB.

### Preview not loading?

The preview may fail to load for unsupported formats or corrupted files. You can still apply the wallpaper by entering the file path manually.

## Notes

- The application stores the wallpaper path in your user registry (`HKCU\Control Panel\Desktop`)
- Network paths (UNC paths) are supported for image files
- Image files are validated before processing to detect corruption
- In GUI mode, the `i` button provides access to a full method reference directly within the application

## License

This project is distributed under the **LGPL v3 (GNU Lesser General Public License v3)**. See the [LICENSE](LICENSE) file for more details.

## Contributing

Contributions, improvements, and pull requests are welcome and greatly appreciated! Feel free to:

- Report issues
- Submit pull requests with improvements
- Suggest new features

Enjoy!