Wallpaper Setter Bypass (WSB)

USAGE (GUI):
1. Unzip this package to a desired location on your computer.
2. Double-click the "launcher.bat" file to run the program.
3. The GUI window will appear.
4. Click "Browse..." to select an image file from your computer.
5. Choose your wallpaper options:
   - Select the target monitor (Current, Primary, DISPLAY#, All, or Spanned)
   - Select a display mode: Tile (repeat) or Full screen
   - In Full screen mode, optionally check "Stretch to fill"
   - Optionally check "Use Registry method" if the default method fails
6. Click the "Apply" button to set the selected image as your wallpaper.
7. Congratulations! Your wallpaper has been successfully changed.

USAGE (Command Line):
1. Open Command Prompt or PowerShell.
2. Navigate to the directory where you unzipped the package using the "cd" command.
3. Run the following command:
   powershell -NoProfile -ExecutionPolicy Bypass -File "wallpaper_setter.ps1" -Path "C:\path\to\image.jpg" [Options]
4. Available options:
   -Path <path>         : Full path to the image file (required)
   -DisplayMode <mode>  : Display mode: 'tile' or 'fullscreen' (default: fullscreen)
   -Monitor <monitor>   : Target monitor: 'primary', 'all', or index (0, 1, 2...) (default: primary)
   -Stretch             : Stretch image to fill screen (fullscreen mode only)
   -Spanned             : Apply as single spanned image across all monitors
   -UseRegistryMethod   : Use registry method instead of native Windows API
   -Help                : Display help message
5. Congratulations! Your wallpaper has been successfully changed.