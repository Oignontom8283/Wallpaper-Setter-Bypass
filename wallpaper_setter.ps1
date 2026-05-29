param(
    [string]$Path,
    [string]$DisplayMode = "fullscreen",
    [string]$Monitor = "primary",
    [switch]$Stretch,
    [switch]$Spanned,
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
  -Monitor <monitor>   Target monitor: 'primary', 'all', 'index' (0, 1, 2...) (default: primary)
  -Stretch             Stretch image to fill screen (fullscreen mode only)
  -Spanned             Apply as single spanned wallpaper across all monitors
  -CloseAfter          Close the application after applying wallpaper
  -UseRegistryMethod   Use registry manipulation method instead of SystemParametersInfo
  -Help                Show this help message

Examples:
  # Interactive GUI mode
  .\wallpaper_setter.ps1

  # CLI mode - apply on primary monitor
  .\wallpaper_setter.ps1 -Path "C:\path\to\image.jpg"

  # CLI mode - apply on all monitors
  .\wallpaper_setter.ps1 -Path "C:\path\to\image.jpg" -Monitor all

  # CLI mode - apply on monitor 2
  .\wallpaper_setter.ps1 -Path "C:\path\to\image.jpg" -Monitor 1

  # CLI mode - spanned across all monitors
  .\wallpaper_setter.ps1 -Path "C:\path\to\image.jpg" -Spanned
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

function Get-MonitorList {
    try {
        # Try using WMI first
        $monitors = @()
        
        # Get monitor info from Windows
        try {
            $displayDevices = Get-WmiObject -Class Win32_PnPDevice -Filter "ClassGuid='{4d36e96e-e325-11ce-bfc1-08002be10318()}'" -ErrorAction SilentlyContinue
            
            if ($displayDevices) {
                $index = 0
                foreach ($device in @($displayDevices)) {
                    $monitorObj = [PSCustomObject]@{
                        Index = $index
                        Name = $device.Name
                        IsPrimary = ($index -eq 0)
                        Screen = $null
                    }
                    $monitors += $monitorObj
                    Write-Host "[DEBUG GET-MONITORLIST] Monitor $index : $($device.Name)"
                    $index++
                }
            }
        } catch {
            Write-Host "[WARNING] WMI method failed, falling back to Screen API"
        }
        
        # Fallback to Screen API if WMI doesn't work
        if ($monitors.Count -eq 0) {
            $screens = [System.Windows.Forms.Screen]::AllScreens
            
            for ($i = 0; $i -lt @($screens).Count; $i++) {
                $screen = @($screens)[$i]
                $isPrimary = $screen.Primary
                $name = "Monitor {0}" -f $i
                if ($isPrimary) {
                    $name = "Monitor {0} (Primary)" -f $i
                }
                
                Write-Host "[DEBUG GET-MONITORLIST] Screen API - Monitor $i : $name"
                
                $monitorObj = [PSCustomObject]@{
                    Index = $i
                    Name = $name
                    IsPrimary = $isPrimary
                    Screen = $screen
                }
                $monitors += $monitorObj
            }
        }
        
        Write-Host "[DEBUG GET-MONITORLIST] Found $($monitors.Count) monitors, type: $($monitors.GetType().Name)"
        return $monitors
    } catch {
        Write-Host "[ERROR] Failed to get monitor list: $_"
        return @()
    }
}

function Get-FocusedMonitor {
    try {
        $focusedWindow = [System.Diagnostics.Process]::GetCurrentProcess().MainWindowHandle
        $screen = [System.Windows.Forms.Screen]::FromHandle($focusedWindow)
        
        $screens = [System.Windows.Forms.Screen]::AllScreens
        for ($i = 0; $i -lt $screens.Count; $i++) {
            if ($screens[$i].DeviceName -eq $screen.DeviceName) {
                return $i
            }
        }
        return 0
    } catch {
        return 0
    }
}

function Test-ImageFile {
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

function Set-WallpaperNative {
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

function Set-WallpaperRegistry {
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

function Set-WallpaperSpanned {
    param(
        [string]$Path,
        [string]$DisplayMode = "fullscreen",
        [bool]$DoStretch = $true
    )
    
    try {
        Write-Host "[INFO] Applying spanned wallpaper across all monitors..."
        
        # Get all screens
        $screens = [System.Windows.Forms.Screen]::AllScreens
        if ($screens.Count -le 1) {
            Write-Host "[WARNING] Only one monitor detected, applying normally"
            return $false
        }
        
        # Calculate total width and determine y position (use primary screen's y)
        $totalWidth = 0
        $minY = 0
        $maxHeight = 0
        $primaryScreen = $screens | Where-Object { $_.Primary }
        
        foreach ($screen in $screens) {
            $totalWidth += $screen.Bounds.Width
            $minY = [Math]::Min($minY, $screen.Bounds.Y)
            $maxHeight = [Math]::Max($maxHeight, $screen.Bounds.Height)
        }
        
        # Create spanned wallpaper by setting registry and using WallpaperStyle 22 (spanned)
        Write-Host "[INFO] Setting wallpaper style to spanned (22)"
        $regPath = 'HKCU:\Control Panel\Desktop'
        Set-ItemProperty -Path $regPath -Name Wallpaper -Value $Path -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name WallpaperStyle -Value 22 -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name TileWallpaper -Value 0 -ErrorAction Stop
        
        Write-Host "[INFO] Refreshing desktop..."
        [WallpaperNative]::SystemParametersInfo(20, 0, $Path, 3) | Out-Null
        
        Write-Host "[SUCCESS] Spanned wallpaper applied"
        return $true
    } catch {
        Write-Host "[ERROR] Failed to apply spanned wallpaper: $($_.Exception.Message)"
        return $false
    }
}

function Set-Wallpaper {
    param(
        [string]$Path,
        [string]$DisplayMode = "fullscreen",
        [string]$Monitor = "primary",
        [bool]$DoStretch,
        [bool]$DoSpanned,
        [bool]$DoCloseAfter,
        [bool]$UseRegistryMethod,
        [bool]$IsGUIMode = $false
    )
    
    Write-Host "[INFO] Applying wallpaper..."
    Write-Host "[INFO] Image path: $Path"
    Write-Host "[INFO] Display mode: $DisplayMode"
    Write-Host "[INFO] Monitor: $Monitor"
    Write-Host "[INFO] Spanned: $DoSpanned"
    Write-Host "[INFO] Stretch: $DoStretch"
    Write-Host "[INFO] Use Registry Method: $UseRegistryMethod"
    
    # Handle spanned mode
    if ($DoSpanned) {
        Write-Host "[INFO] Spanned mode enabled, applying to all monitors"
        if (Set-WallpaperSpanned -Path $Path -DisplayMode $DisplayMode -DoStretch $DoStretch) {
            Write-Host "[SUCCESS] Wallpaper applied successfully!"
            return $true
        } else {
            Write-Host "[ERROR] Failed to apply spanned wallpaper"
            return $false
        }
    }
    
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        Write-Host "[ERROR] Invalid image path"
        if ($IsGUIMode) {
            [System.Windows.Forms.MessageBox]::Show('Please select a valid image file.', 'Error', 'OK', 'Error') | Out-Null
        }
        return $false
    }
    
    # Validate image file
    if (-not (Test-ImageFile -ImagePath $Path)) {
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
        $success = Set-WallpaperRegistry -Path $walpaperPath -DisplayMode $DisplayMode
    } else {
        # Try native method first
        $success = Set-WallpaperNative -Path $walpaperPath
        
        # If native fails and we're in GUI mode, ask user to try registry method
        if (-not $success -and $IsGUIMode) {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "SystemParametersInfo method failed. Would you like to try the Registry method?`n`nThis might work better on some systems.",
                'Method Failed',
                'YesNo',
                'Question'
            )
            
            if ($result -eq 'Yes') {
                $success = Set-WallpaperRegistry -Path $walpaperPath -DisplayMode $DisplayMode
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
    if (Set-Wallpaper -Path $Path -DisplayMode $DisplayMode -Monitor $Monitor -DoStretch $Stretch -DoSpanned $Spanned -DoCloseAfter $CloseAfter -UseRegistryMethod $UseRegistryMethod -IsGUIMode $false) {
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
$form.Size = New-Object System.Drawing.Size(800, 500)
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

# Monitor selection group
$monitorLabel = New-Object System.Windows.Forms.Label
$monitorLabel.Text = 'Monitor:'
$monitorLabel.AutoSize = $true
$monitorLabel.Location = New-Object System.Drawing.Point(12, 143)

$monitorComboBox = New-Object System.Windows.Forms.ComboBox
$monitorComboBox.Location = New-Object System.Drawing.Point(85, 143)
$monitorComboBox.Size = New-Object System.Drawing.Size(200, 22)
$monitorComboBox.DropDownStyle = 'DropDownList'
$monitorComboBox.Items.Add('Current')
$monitorComboBox.Items.Add('Primary')

# Get monitor info and add to dropdown - include ALL monitors
$monitors = Get-MonitorList
Write-Host "[DEBUG] Found $(@($monitors).Count) monitors"
Write-Host "[DEBUG] Monitors object type: $($monitors.GetType().Name)"
for ($i = 0; $i -lt @($monitors).Count; $i++) {
    $monitor = @($monitors)[$i]
    Write-Host "[DEBUG] Monitor ${i} - Object type: $($monitor.GetType().Name)"
    Write-Host "[DEBUG] Monitor ${i} - Object: $($monitor | Out-String)"
    Write-Host "[DEBUG] Monitor ${i}: Name='$($monitor.Name)'"
    if ($monitor.Name) {
        $monitorComboBox.Items.Add($monitor.Name)
    }
}

$monitorComboBox.Items.Add('All')
$monitorComboBox.Items.Add('Spanned')
$monitorComboBox.SelectedIndex = 0

$closeAfterCheckBox = New-Object System.Windows.Forms.CheckBox
$closeAfterCheckBox.Text = 'Close after applying'
$closeAfterCheckBox.Location = New-Object System.Drawing.Point(12, 220)
$closeAfterCheckBox.Size = New-Object System.Drawing.Size(150, 22)
$closeAfterCheckBox.Checked = $true

$useRegistryCheckBox = New-Object System.Windows.Forms.CheckBox
$useRegistryCheckBox.Text = 'Use Registry method'
$useRegistryCheckBox.Location = New-Object System.Drawing.Point(12, 245)
$useRegistryCheckBox.Size = New-Object System.Drawing.Size(150, 22)
$useRegistryCheckBox.Checked = $false

$applyButton = New-Object System.Windows.Forms.Button
$applyButton.Text = 'Apply'
$applyButton.Location = New-Object System.Drawing.Point(12, 280)
$applyButton.Size = New-Object System.Drawing.Size(90, 30)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = 'Exit'
$exitButton.Location = New-Object System.Drawing.Point(112, 280)
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
$tooltip.SetToolTip($monitorComboBox, "Choose which monitor to apply the wallpaper to`nCurrent: The monitor where this window is located`nPrimary: Main system monitor`nSpanned: One image across all monitors")
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
    
    # Determine monitor selection and spanned mode
    $monitorSelection = $monitorComboBox.SelectedItem
    $selectedMonitor = "primary"
    $isSpanned = $false
    
    if ($monitorSelection -eq 'Spanned') {
        $isSpanned = $true
    } elseif ($monitorSelection -eq 'Current') {
        $focusedMonitorIndex = Get-FocusedMonitor
        $selectedMonitor = $focusedMonitorIndex.ToString()
    } elseif ($monitorSelection -eq 'All') {
        $selectedMonitor = "all"
    } elseif ($monitorSelection -eq 'Primary') {
        $selectedMonitor = "primary"
    } else {
        # If it's a specific monitor name, use it
        $selectedMonitor = $monitorSelection
    }
    
    if (Set-Wallpaper -Path $selectedPath -DisplayMode $displayMode -Monitor $selectedMonitor -DoStretch $stretchCheckBox.Checked -DoSpanned $isSpanned -DoCloseAfter $closeAfterCheckBox.Checked -UseRegistryMethod $useRegistryCheckBox.Checked -IsGUIMode $true) {
        [System.Windows.Forms.MessageBox]::Show('Wallpaper applied successfully!', 'Success', 'OK', 'Information') | Out-Null
        if ($closeAfterCheckBox.Checked) {
            $form.Close()
        }
    }
})

$form.Controls.AddRange(@($label, $pathBox, $browseButton, $displayModeLabel, $tileRadioButton, $fullscreenRadioButton, $stretchCheckBox, $closeAfterCheckBox, $useRegistryCheckBox, $monitorLabel, $monitorComboBox, $applyButton, $exitButton, $previewBox))
$form.ShowDialog() | Out-Null
