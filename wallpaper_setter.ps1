param(
    [string]$Path,
    [string]$DisplayMode = "fullscreen",
    [switch]$Stretch,
    [switch]$CloseAfter,
    [switch]$UseRegistryMethod,
    [switch]$Help
)

$AppName = "Wallpaper Setter Bypass"

if ($Help -or ([string]::IsNullOrWhiteSpace($Path) -and $Help)) {
    Write-Host @"
$AppName PowerShell Script

Usage:
  .\wallpaper_setter.ps1 [Options]

Options:
  -Path <path>         Set the wallpaper directly (CLI mode, no GUI)
  -DisplayMode         Display mode: 'tile' or 'fullscreen' (default: fullscreen)
  -Stretch             Stretch image to fill screen instead of maintaining aspect ratio (for fullscreen mode)
  -CloseAfter          Close the application after applying wallpaper
  -UseRegistryMethod   Use registry manipulation method instead of SystemParametersInfo
  -Help                Show this help message

Examples:
  # Interactive GUI mode
  .\wallpaper_setter.ps1

  # CLI mode - apply image as tiled
  .\wallpaper_setter.ps1 -Path "C:\path\to\image.jpg" -DisplayMode tile

  # CLI mode - apply image fullscreen with stretch
  .\wallpaper_setter.ps1 -Path "C:\path\to\image.jpg" -DisplayMode fullscreen -Stretch

  # CLI mode - apply image with registry method
  .\wallpaper_setter.ps1 -Path "C:\path\to\image.jpg" -UseRegistryMethod
"@
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WallpaperNative {
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@

function Validate-ImageFile {
    param(
        [string]$ImagePath
    )
    
    try {
        Write-Host "[INFO] Validating image file: $ImagePath"
        $image = [System.Drawing.Image]::FromFile($ImagePath)
        $imageWidth = $image.Width
        $imageHeight = $image.Height
        $image.Dispose()
        
        Write-Host "[INFO] Image validation successful: $($imageWidth)x$($imageHeight)"
        return $true
    } catch {
        Write-Host "[ERROR] Invalid or corrupted image file: $($_.Exception.Message)"
        return $false
    }
}

function Apply-WallpaperNative {
    param(
        [string]$Path
    )
    
    try {
        Write-Host "[INFO] Attempting SystemParametersInfo method..."
        [WallpaperNative]::SystemParametersInfo(20, 0, $Path, 3) | Out-Null
        Write-Host "[SUCCESS] SystemParametersInfo method succeeded"
        return $true
    } catch {
        Write-Host "[ERROR] SystemParametersInfo method failed: $($_.Exception.Message)"
        return $false
    }
}

function Apply-WallpaperRegistry {
    param(
        [string]$Path,
        [string]$DisplayMode = "fullscreen"
    )
    
    try {
        Write-Host "[INFO] Attempting Registry method..."
        
        # Set registry values
        Write-Host "[INFO] Setting wallpaper registry values..."
        $regPath = 'HKCU:\Control Panel\Desktop'
        Set-ItemProperty -Path $regPath -Name Wallpaper -Value $Path -ErrorAction Stop
        
        # Set TileWallpaper based on display mode
        if ($DisplayMode -eq "tile") {
            Write-Host "[INFO] Setting TileWallpaper to 1 (tile mode)"
            Set-ItemProperty -Path $regPath -Name TileWallpaper -Value 1 -ErrorAction Stop
        } else {
            Write-Host "[INFO] Setting TileWallpaper to 0 (no tile)"
            Set-ItemProperty -Path $regPath -Name TileWallpaper -Value 0 -ErrorAction Stop
        }
        
        Write-Host "[INFO] Refreshing desktop with SystemParametersInfo..."
        [WallpaperNative]::SystemParametersInfo(20, 0, $Path, 3) | Out-Null
        
        Write-Host "[SUCCESS] Registry method succeeded"
        return $true
    } catch {
        Write-Host "[ERROR] Registry method failed: $($_.Exception.Message)"
        return $false
    }
}

function Apply-Wallpaper {
    param(
        [string]$Path,
        [string]$DisplayMode = "fullscreen",
        [bool]$DoStretch,
        [bool]$DoCloseAfter,
        [bool]$UseRegistryMethod,
        [bool]$IsGUIMode = $false
    )
    
    Write-Host "[INFO] Applying wallpaper..."
    Write-Host "[INFO] Image path: $Path"
    Write-Host "[INFO] Display mode: $DisplayMode"
    Write-Host "[INFO] Stretch: $DoStretch"
    Write-Host "[INFO] Use Registry Method: $UseRegistryMethod"
    
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        Write-Host "[ERROR] Invalid image path"
        if ($IsGUIMode) {
            [System.Windows.Forms.MessageBox]::Show('Please select a valid image file.', 'Error', 'OK', 'Error') | Out-Null
        }
        return $false
    }
    
    # Validate image file
    if (-not (Validate-ImageFile -ImagePath $Path)) {
        Write-Host "[ERROR] Image file validation failed"
        if ($IsGUIMode) {
            [System.Windows.Forms.MessageBox]::Show('Selected file is not a valid image or is corrupted.', 'Error', 'OK', 'Error') | Out-Null
        }
        return $false
    }
    
    $walpaperPath = $Path
    
    # Set wallpaper style in registry based on display mode
    Write-Host "[INFO] Setting wallpaper style..."
    if ($DisplayMode -eq "tile") {
        Write-Host "[INFO] Setting style to: Tile"
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value 1
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value 1
    } elseif ($DoStretch) {
        Write-Host "[INFO] Setting style to: Stretch"
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value 2
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value 0
    } else {
        Write-Host "[INFO] Setting style to: Center"
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value 6
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value 0
    }
    
    $success = $false
    
    # Try preferred method
    if ($UseRegistryMethod) {
        $success = Apply-WallpaperRegistry -Path $walpaperPath -DisplayMode $DisplayMode
    } else {
        # Try native method first
        $success = Apply-WallpaperNative -Path $walpaperPath
        
        # If native fails and we're in GUI mode, ask user to try registry method
        if (-not $success -and $IsGUIMode) {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "SystemParametersInfo method failed. Would you like to try the Registry method?`n`nThis might work better on some systems.",
                'Method Failed',
                'YesNo',
                'Question'
            )
            
            if ($result -eq 'Yes') {
                $success = Apply-WallpaperRegistry -Path $walpaperPath -DisplayMode $DisplayMode
            }
        }
    }
    
    if ($success) {
        Write-Host "[SUCCESS] Wallpaper applied successfully!"
        return $true
    } else {
        Write-Host "[ERROR] Failed to apply wallpaper with all methods"
        return $false
    }
}

if (-not [string]::IsNullOrWhiteSpace($Path)) {
    Write-Host "=== $AppName - CLI Mode ===" -ForegroundColor Cyan
    if (Apply-Wallpaper -Path $Path -DisplayMode $DisplayMode -DoStretch $Stretch -DoCloseAfter $CloseAfter -UseRegistryMethod $UseRegistryMethod -IsGUIMode $false) {
        [System.Windows.Forms.MessageBox]::Show('Wallpaper applied successfully!', 'Success', 'OK', 'Information') | Out-Null
        if ($CloseAfter) {
            exit
        }
    }
    exit
}

[System.Windows.Forms.Application]::EnableVisualStyles()

Write-Host "=== $AppName - GUI Mode ===" -ForegroundColor Cyan

$form = New-Object System.Windows.Forms.Form
$form.Text = $AppName
$form.Size = New-Object System.Drawing.Size(800, 420)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$label = New-Object System.Windows.Forms.Label
$label.Text = 'Selected image:'
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(12, 20)

$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.Location = New-Object System.Drawing.Point(120, 16)
$pathBox.Size = New-Object System.Drawing.Size(200, 22)
$pathBox.ReadOnly = $true

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = 'Browse...'
$browseButton.Location = New-Object System.Drawing.Point(330, 14)
$browseButton.Size = New-Object System.Drawing.Size(75, 25)

# Display mode group
$displayModeLabel = New-Object System.Windows.Forms.Label
$displayModeLabel.Text = 'Display mode:'
$displayModeLabel.AutoSize = $true
$displayModeLabel.Location = New-Object System.Drawing.Point(12, 50)

$tileRadioButton = New-Object System.Windows.Forms.RadioButton
$tileRadioButton.Text = 'Tile (repeat)'
$tileRadioButton.Location = New-Object System.Drawing.Point(12, 70)
$tileRadioButton.Size = New-Object System.Drawing.Size(150, 22)
$tileRadioButton.Checked = $false

$fullscreenRadioButton = New-Object System.Windows.Forms.RadioButton
$fullscreenRadioButton.Text = 'Full screen'
$fullscreenRadioButton.Location = New-Object System.Drawing.Point(12, 95)
$fullscreenRadioButton.Size = New-Object System.Drawing.Size(150, 22)
$fullscreenRadioButton.Checked = $true

$stretchCheckBox = New-Object System.Windows.Forms.CheckBox
$stretchCheckBox.Text = 'Stretch to fill'
$stretchCheckBox.Location = New-Object System.Drawing.Point(35, 120)
$stretchCheckBox.Size = New-Object System.Drawing.Size(150, 22)
$stretchCheckBox.Checked = $true
$stretchCheckBox.Enabled = $true

# Update stretch checkbox state based on radio button selection
$tileRadioButton.Add_CheckedChanged({
    $stretchCheckBox.Enabled = -not $tileRadioButton.Checked
    if ($tileRadioButton.Checked) {
        $stretchCheckBox.Checked = $false
    }
})

$fullscreenRadioButton.Add_CheckedChanged({
    $stretchCheckBox.Enabled = $fullscreenRadioButton.Checked
})

$closeAfterCheckBox = New-Object System.Windows.Forms.CheckBox
$closeAfterCheckBox.Text = 'Close after applying'
$closeAfterCheckBox.Location = New-Object System.Drawing.Point(12, 145)
$closeAfterCheckBox.Size = New-Object System.Drawing.Size(150, 22)
$closeAfterCheckBox.Checked = $true

$useRegistryCheckBox = New-Object System.Windows.Forms.CheckBox
$useRegistryCheckBox.Text = 'Use Registry method'
$useRegistryCheckBox.Location = New-Object System.Drawing.Point(12, 170)
$useRegistryCheckBox.Size = New-Object System.Drawing.Size(150, 22)
$useRegistryCheckBox.Checked = $false

$applyButton = New-Object System.Windows.Forms.Button
$applyButton.Text = 'Apply'
$applyButton.Location = New-Object System.Drawing.Point(12, 205)
$applyButton.Size = New-Object System.Drawing.Size(90, 30)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = 'Exit'
$exitButton.Location = New-Object System.Drawing.Point(112, 205)
$exitButton.Size = New-Object System.Drawing.Size(90, 30)

$previewBox = New-Object System.Windows.Forms.PictureBox
$previewBox.Location = New-Object System.Drawing.Point(450, 16)
$previewBox.Size = New-Object System.Drawing.Size(330, 290)
$previewBox.BorderStyle = 'FixedSingle'
$previewBox.SizeMode = 'Zoom'
$previewBox.BackColor = [System.Drawing.Color]::LightGray

$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = 'Images|*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.tif;*.tiff'
$dialog.Multiselect = $false

# Create tooltip for all controls
$tooltip = New-Object System.Windows.Forms.ToolTip
$tooltip.AutoPopDelay = 5000
$tooltip.InitialDelay = 500
$tooltip.ReshowDelay = 500
$tooltip.ShowAlways = $false

# Add tooltips to controls
$tooltip.SetToolTip($browseButton, "Browse and select an image file to set as wallpaper")
$tooltip.SetToolTip($tileRadioButton, "Display mode: Tile repeats the image across the entire screen")
$tooltip.SetToolTip($fullscreenRadioButton, "Display mode: Full screen displays the image centered or stretched without tiling")
$tooltip.SetToolTip($stretchCheckBox, "When enabled: Stretches image to fill screen`nWhen disabled: Centers image on the screen (keeps aspect ratio)")
$tooltip.SetToolTip($closeAfterCheckBox, "Automatically close the application after the wallpaper is applied")
$tooltip.SetToolTip($useRegistryCheckBox, "Use registry method instead of Windows API (try this if the default method fails on restricted systems)")
$tooltip.SetToolTip($applyButton, "Apply the selected wallpaper with the chosen settings")
$tooltip.SetToolTip($exitButton, "Close the application without applying changes")
$tooltip.SetToolTip($previewBox, "Preview of the selected image")

$browseButton.Add_Click({
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $pathBox.Text = $dialog.FileName
        try {
            $previewBox.Image = [System.Drawing.Image]::FromFile($dialog.FileName)
        } catch {
            [System.Windows.Forms.MessageBox]::Show('Could not load preview image.', 'Warning', 'OK', 'Warning') | Out-Null
        }
    }
})

$exitButton.Add_Click({
    $form.Close()
})

$applyButton.Add_Click({
    Write-Host ""
    Write-Host "=== Applying Wallpaper (GUI Mode) ===" -ForegroundColor Cyan
    $selectedPath = $pathBox.Text
    
    # Determine display mode
    $displayMode = if ($tileRadioButton.Checked) { "tile" } else { "fullscreen" }
    
    if (Apply-Wallpaper -Path $selectedPath -DisplayMode $displayMode -DoStretch $stretchCheckBox.Checked -DoCloseAfter $closeAfterCheckBox.Checked -UseRegistryMethod $useRegistryCheckBox.Checked -IsGUIMode $true) {
        [System.Windows.Forms.MessageBox]::Show('Wallpaper applied successfully!', 'Success', 'OK', 'Information') | Out-Null
        if ($closeAfterCheckBox.Checked) {
            $form.Close()
        }
    }
})

$form.Controls.AddRange(@($label, $pathBox, $browseButton, $displayModeLabel, $tileRadioButton, $fullscreenRadioButton, $stretchCheckBox, $closeAfterCheckBox, $useRegistryCheckBox, $applyButton, $exitButton, $previewBox))
$form.ShowDialog() | Out-Null
