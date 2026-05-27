param(
    [string]$ImagePath,
    [switch]$ScaleUp,
    [switch]$Stretch,
    [switch]$CloseAfter,
    [switch]$Help
)

if ($Help -or ([string]::IsNullOrWhiteSpace($ImagePath) -and $Help)) {
    Write-Host @"
Wallpaper Setter PowerShell Script

Usage:
  .\wallpaper_gui.ps1 [Options]

Options:
  -ImagePath <path>    Set the wallpaper directly (CLI mode, no GUI)
  -ScaleUp             Scale up small images to screen resolution (nearest neighbor)
  -Stretch             Stretch image to fill screen instead of maintaining aspect ratio
  -CloseAfter          Close the application after applying wallpaper
  -Help                Show this help message

Examples:
  # Interactive GUI mode
  .\wallpaper_gui.ps1

  # CLI mode - apply image directly
  .\wallpaper_gui.ps1 -ImagePath "C:\path\to\image.jpg" -ScaleUp -Stretch -CloseAfter

  # CLI mode - apply image with scaling
  .\wallpaper_gui.ps1 -ImagePath "C:\path\to\image.jpg" -ScaleUp
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

function Scale-ImageUp {
    param(
        [string]$ImagePath,
        [string]$OutputPath
    )
    
    try {
        Write-Host "[INFO] Loading image: $ImagePath"
        $originalImage = [System.Drawing.Image]::FromFile($ImagePath)
        Write-Host "[INFO] Image dimensions: $($originalImage.Width)x$($originalImage.Height)"
        
        $screenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
        $screenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
        Write-Host "[INFO] Screen dimensions: $screenWidth`x$screenHeight"
        
        if ($originalImage.Width -ge $screenWidth -and $originalImage.Height -ge $screenHeight) {
            Write-Host "[INFO] Image already meets screen dimensions, skipping scale"
            $originalImage.Dispose()
            return $ImagePath
        }
        
        $scaleX = [Math]::Floor($screenWidth / $originalImage.Width)
        $scaleY = [Math]::Floor($screenHeight / $originalImage.Height)
        $scale = [Math]::Min($scaleX, $scaleY)
        
        if ($scale -lt 2) {
            Write-Host "[INFO] Scale factor ($scale) too small, skipping scale"
            $originalImage.Dispose()
            return $ImagePath
        }
        
        Write-Host "[INFO] Scaling image by factor: $scale`x"
        
        $newWidth = $originalImage.Width * $scale
        $newHeight = $originalImage.Height * $scale
        Write-Host "[INFO] New dimensions: $newWidth`x$newHeight"
        
        # Create bitmap with explicit PixelFormat
        Write-Host "[INFO] Creating scaled bitmap..."
        $scaledBitmap = New-Object System.Drawing.Bitmap($newWidth, $newHeight, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        
        $graphics = [System.Drawing.Graphics]::FromImage($scaledBitmap)
        $graphics.Clear([System.Drawing.Color]::Black)
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighSpeed
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        
        Write-Host "[INFO] Drawing scaled image..."
        $graphics.DrawImage($originalImage, 0, 0, $newWidth, $newHeight)
        
        Write-Host "[INFO] Saving scaled image to: $OutputPath"
        $encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/bmp' } | Select-Object -First 1
        $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(0)
        $scaledBitmap.Save($OutputPath, $encoder, $encoderParams)
        
        $graphics.Dispose()
        $scaledBitmap.Dispose()
        $originalImage.Dispose()
        
        Write-Host "[SUCCESS] Image scaled successfully"
        return $OutputPath
    } catch {
        Write-Host "[ERROR] Error scaling image: $($_.Exception.Message)"
        Write-Host "[ERROR] Full error: $_"
        try { $originalImage.Dispose() } catch {}
        return $ImagePath
    }
}

function Apply-Wallpaper {
    param(
        [string]$Path,
        [bool]$DoScaleUp,
        [bool]$DoStretch,
        [bool]$DoCloseAfter
    )
    
    Write-Host "[INFO] Applying wallpaper..."
    Write-Host "[INFO] Image path: $Path"
    Write-Host "[INFO] Scale up: $DoScaleUp"
    Write-Host "[INFO] Stretch: $DoStretch"
    
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        Write-Host "[ERROR] Invalid image path"
        [System.Windows.Forms.MessageBox]::Show('Please select a valid image file.', 'Error', 'OK', 'Error') | Out-Null
        return $false
    }
    
    $walpaperPath = $Path
    
    if ($DoScaleUp) {
        Write-Host "[INFO] Scaling image..."
        $tempPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "wallpaper_scaled_$(Get-Random).bmp")
        $walpaperPath = Scale-ImageUp -ImagePath $Path -OutputPath $tempPath
    }
    
    Write-Host "[INFO] Setting wallpaper registry values..."
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value $walpaperPath
    
    if ($DoStretch) {
        Write-Host "[INFO] Setting style to: Stretch"
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value 2
    } else {
        Write-Host "[INFO] Setting style to: Center"
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value 6
    }
    
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value 0
    
    Write-Host "[INFO] Refreshing desktop..."
    [WallpaperNative]::SystemParametersInfo(20, 0, $walpaperPath, 3) | Out-Null
    
    Write-Host "[SUCCESS] Wallpaper applied successfully!"
    return $true
}

if (-not [string]::IsNullOrWhiteSpace($ImagePath)) {
    Write-Host "=== Wallpaper Setter - CLI Mode ===" -ForegroundColor Cyan
    if (Apply-Wallpaper -Path $ImagePath -DoScaleUp $ScaleUp -DoStretch $Stretch -DoCloseAfter $CloseAfter) {
        [System.Windows.Forms.MessageBox]::Show('Wallpaper applied successfully!', 'Success', 'OK', 'Information') | Out-Null
        if ($CloseAfter) {
            exit
        }
    }
    exit
}

[System.Windows.Forms.Application]::EnableVisualStyles()

Write-Host "=== Wallpaper Setter - GUI Mode ===" -ForegroundColor Cyan

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Wallpaper Setter'
$form.Size = New-Object System.Drawing.Size(800, 380)
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

$stretchCheckBox = New-Object System.Windows.Forms.CheckBox
$stretchCheckBox.Text = 'Stretch to fill screen'
$stretchCheckBox.Location = New-Object System.Drawing.Point(12, 50)
$stretchCheckBox.Size = New-Object System.Drawing.Size(150, 22)
$stretchCheckBox.Checked = $false

$scaleUpCheckBox = New-Object System.Windows.Forms.CheckBox
$scaleUpCheckBox.Text = 'Scale up small images'
$scaleUpCheckBox.Location = New-Object System.Drawing.Point(12, 75)
$scaleUpCheckBox.Size = New-Object System.Drawing.Size(150, 22)
$scaleUpCheckBox.Checked = $false

$closeAfterCheckBox = New-Object System.Windows.Forms.CheckBox
$closeAfterCheckBox.Text = 'Close after applying'
$closeAfterCheckBox.Location = New-Object System.Drawing.Point(12, 100)
$closeAfterCheckBox.Size = New-Object System.Drawing.Size(150, 22)
$closeAfterCheckBox.Checked = $true

$applyButton = New-Object System.Windows.Forms.Button
$applyButton.Text = 'Apply'
$applyButton.Location = New-Object System.Drawing.Point(12, 135)
$applyButton.Size = New-Object System.Drawing.Size(90, 30)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = 'Exit'
$exitButton.Location = New-Object System.Drawing.Point(112, 135)
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
    if (Apply-Wallpaper -Path $selectedPath -DoScaleUp $scaleUpCheckBox.Checked -DoStretch $stretchCheckBox.Checked -DoCloseAfter $closeAfterCheckBox.Checked) {
        [System.Windows.Forms.MessageBox]::Show('Wallpaper applied successfully!', 'Success', 'OK', 'Information') | Out-Null
        if ($closeAfterCheckBox.Checked) {
            $form.Close()
        }
    }
})

$form.Controls.AddRange(@($label, $pathBox, $browseButton, $stretchCheckBox, $scaleUpCheckBox, $closeAfterCheckBox, $applyButton, $exitButton, $previewBox))
$form.ShowDialog() | Out-Null

