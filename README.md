# Wallpaper Setter Bypass (WSB)

<img src="https://img.shields.io/badge/Target-Windows-green?style=flat" alt="Target Hardware"/>

[Français](README_FR.md) | **English**

A PowerShell application that bypasses the native Windows wallpaper settings to apply wallpapers directly with advanced scaling and styling options. Works without administrator privileges.

![Illustration of WSB GUI](./assets/gui.png)

![Demo GIF Animation](./assets/demo.gif)


## Features

- [x] **Dual Method Support**: Choose between native Windows API or registry manipulation methods
- [x] **GUI Mode**: Interactive graphical interface for easy wallpaper selection
- [x] **CLI Mode**: Command-line interface for automation and scripting
- [x] **Image Validation**: Automatic validation to detect corrupted or invalid image files
- [x] **Display Modes**: Choose between Tile (repeat) or Fullscreen display
- [x] **Stretch Options**: In fullscreen mode, choose between centered or stretched display
- [x] **Image Preview**: Live preview of selected images before applying
- [x] **Auto-Close**: Option to automatically close the application after applying wallpaper
- [x] **No Admin Required**: Works without administrator privileges using registry-based methods

## Supported Image Formats

- JPG / JPEG
- PNG
- BMP
- GIF
- TIFF / TIF

## Requirements

- Windows 7 or later
- PowerShell 3.0 or later
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

1. Click **`Browse...`** to select an image file
2. View the image preview on the right side
3. Select the display mode:
   - **Tile (repeat)**: Repeats the image across the entire screen
   - **Full screen**: Displays the image in full screen
4. In fullscreen mode, check optional options:
   - **Stretch to fill**: Stretches the image to fill the entire screen (otherwise it will be centered)
5. Check other options:
   - **Close after applying**: Automatically closes the window after setting the wallpaper
   - **Use Registry method**: Use registry manipulation method instead of native Windows API (try this if the default method fails)
6. Click **`Apply`** to set the wallpaper
7. Click **`Exit`** to close without applying changes

### CLI Mode (Command Line)

Use the following syntax for command-line usage:

```powershell
.\wallpaper_setter.ps1 -Path "C:\path\to\image.jpg" [Options]
```

####DisplayMode <mode>`: Display mode: `tile` (repeat) or `fullscreen` (default)
- `-Stretch`: Stretch image to fill screen (fullscreen mode only)
- `-Path <path>` (required): Full path to the image file
- `-ScaleUp`: Scale up small images to screen resolution
- `-Stretch`: Stretch image to fill screen instead of maintaining aspect ratio
- `-CloseAfter`: Close the application after applying wallpaper
- `-UseRegistryMethod`: Use registry manipulation method instead of native API
- `-Help`: Display help message

#### Examples:

Apply an image in fullscreen centered mode:

```powershell
.\wallpaper_setter.ps1 -Path "C:\Users\MyUser\Pictures\image.jpg" -DisplayMode fullscreen
```

Apply an image in fullscreen stretched mode:

```powershell
.\wallpaper_setter.ps1 -Path "C:\Users\MyUser\Pictures\image.jpg" -DisplayMode fullscreen -Stretch
```

Apply an image in tile mode (repeat):

```powershell
.\wallpaper_setter.ps1 -Path "C:\Users\MyUser\Pictures\image.jpg" -DisplayMode tile
```

Apply an image with auto-close:

```powershell
.\wallpaper_setter.ps1 -Path "C:\Users\MyUser\Pictures\image.jpg" -DisplayMode fullscreen -Stretch -CloseAfter
```

Apply an image using the registry method:

```powershell
.\wallpaper_setter.ps1 -Path "C:\Users\MyUser\Pictures\image.jpg" -UseRegistryMethod
```

View help:

```powershell
.\wallpaper_setter.ps1 -Help
```

## How It Works

WSB bypasses the standard Windows Settings GUI by directly modifying wallpaper configuration:

1. **GUI Mode**: Launches an interactive window using Windows Forms to select and configure wallpaper settings
2. **Display Modes**:
   - **Tile**: Repeats the image across the entire screen (WallpaperStyle=1, TileWallpaper=1)
   - **Fullscreen Centered**: Displays the image centered without repetition (WallpaperStyle=6, TileWallpaper=0)
   - **Fullscreen Stretched**: Displays the image stretched to fill the screen (WallpaperStyle=2, TileWallpaper=0)
3. **Dual Method Approach**:
   - **Default Method**: Uses native Windows API (`SystemParametersInfo`) for direct wallpaper refresh
   - **Registry Method**: Directly manipulates Windows registry settings:
     - `Wallpaper`: Path to the wallpaper image
     - `WallpaperStyle`: 1 for tile, 2 for stretch, 6 for centered
     - `TileWallpaper`: 1 for tiling, 0 for no tiling
4. **Fallback Strategy**: If the default method fails in GUI mode, automatically offers to try the registry method
5. **Desktop Refresh**: Triggers immediate wallpaper display without requiring system restart

## Troubleshooting

### PowerShell execution policy error?

If you see "File cannot be loaded because running scripts is disabled", use the launcher batch file instead:

```cmd
launcher.bat
```

This bypasses execution policy restrictions. Alternatively, enable script execution:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
```

### Image not applying?

- Check that the image file path is correct
- Verify the image file is in a supported format and not corrupted
- Try using the `-UseRegistryMethod` flag if the default method doesn't work
- Ensure the Windows Registry is accessible (not restricted by group policies)

### Registry method is slow or not working?

The registry method may take a moment to refresh the wallpaper. If it doesn't apply immediately:

- Wait a few seconds and the wallpaper should update
- Try applying again - sometimes the registry method requires multiple attempts to take effect
- Use the launcher batch file if execution policy is preventing the PowerShell script from running

### Preview not loading?

The preview may fail to load for unsupported formats. You can still apply the wallpaper using the image file path.

## Notes

- Temporary scaled images are automatically cleaned up after wallpaper is applied
- The application stores the wallpaper path in your user registry
- Network paths (UNC paths) are supported for image files
- Image files are validated before processing to detect corruption

## License

This project is distributed under the **LGPL v3 (GNU Lesser General Public License v3)**. See the [LICENSE](LICENSE) file for more details.

## Contributing

Contributions, improvements, and pull requests are welcome and greatly appreciated! Feel free to:

- Report issues
- Submit pull requests with improvements
- Suggest new features
- etc

Enjoy!
