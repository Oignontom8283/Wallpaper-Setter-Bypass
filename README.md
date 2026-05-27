# Wallpaper Setter Bypass (WSB)

[Français](README_FR.md) | **English**

A PowerShell application that bypasses the native Windows wallpaper settings to apply wallpapers directly with advanced scaling and styling options. Works without administrator privileges.

![Illustration of WSB GUI](./assets/gui.png)

![Demo GIF Animation](./assets/demo.gif)


## Features

- [x] **Dual Method Support**: Choose between native Windows API or registry manipulation methods
- [x] **GUI Mode**: Interactive graphical interface for easy wallpaper selection
- [x] **GUI Mode**: Interactive graphical interface for easy wallpaper selection
- [x] **CLI Mode**: Command-line interface for automation and scripting
- [x] **Image Scaling**: Scale up small images to screen resolution using nearest-neighbor interpolation
- [x] **Stretch Options**: Choose between centered or stretched wallpaper display
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
3. Check optional options:
   - **Stretch to fill screen**: Stretches the image to fill the entire screen
   - **Scale up small images**: Enlarges images smaller than your screen resolution
   - **Close after applying**: Automatically closes the window after setting the wallpaper
   - **Use Registry method**: Use registry manipulation method instead of native Windows API (try this if the default method fails)
4. Click **`Apply`** to set the wallpaper
5. Click **`Exit`** to close without applying changes

### CLI Mode (Command Line)

Use the following syntax for command-line usage:

```powershell
.\wallpaper_setter.ps1 -Path "C:\path\to\image.jpg" [Options]
```

#### Options:

- `-Path <path>` (required): Full path to the image file
- `-ScaleUp`: Scale up small images to screen resolution
- `-Stretch`: Stretch image to fill screen instead of maintaining aspect ratio
- `-CloseAfter`: Close the application after applying wallpaper
- `-UseRegistryMethod`: Use registry manipulation method instead of native API
- `-Help`: Display help message

#### Examples:

Apply an image with scaling:

```powershell
.\wallpaper_setter.ps1 -Path "C:\Users\MyUser\Pictures\image.jpg" -ScaleUp
```

Apply an image stretched to fill the screen:

```powershell
.\wallpaper_setter.ps1 -Path "C:\Users\MyUser\Pictures\image.jpg" -Stretch
```

Apply an image with all options and auto-close:

```powershell
.\wallpaper_setter.ps1 -Path "C:\Users\MyUser\Pictures\image.jpg" -ScaleUp -Stretch -CloseAfter
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
2. **Image Scaling**: If scaling is enabled, the image is enlarged using nearest-neighbor interpolation to match your screen resolution while maintaining quality
3. **Dual Method Approach**:
   - **Default Method**: Uses native Windows API (`SystemParametersInfo`) for direct wallpaper refresh
   - **Registry Method**: Directly manipulates Windows registry settings:
     - `Wallpaper`: Path to the wallpaper image
     - `WallpaperStyle`: 2 for stretch, 6 for centered
     - `TileWallpaper`: Set to 0 (no tiling)
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
- Verify the image file is in a supported format
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

- Temporary scaled images are stored in the Windows temp folder and can be cleaned up manually
- The application stores the wallpaper path in your user registry
- Network paths (UNC paths) are supported for image files

## License

This project is distributed under the **LGPL v3 (GNU Lesser General Public License v3)**. See the [LICENSE](LICENSE) file for more details.

## Contributing

Contributions, improvements, and pull requests are welcome and greatly appreciated! Feel free to:

- Report issues
- Submit pull requests with improvements
- Suggest new features
- etc

Enjoy!
