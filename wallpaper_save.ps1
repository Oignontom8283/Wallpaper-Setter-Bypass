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

[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Wallpaper Setter'
$form.Size = New-Object System.Drawing.Size(520, 170)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$label = New-Object System.Windows.Forms.Label
$label.Text = 'Selected image:'
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(12, 20)

$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.Location = New-Object System.Drawing.Point(120, 16)
$pathBox.Size = New-Object System.Drawing.Size(290, 22)
$pathBox.ReadOnly = $true

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = 'Browse...'
$browseButton.Location = New-Object System.Drawing.Point(420, 14)
$browseButton.Size = New-Object System.Drawing.Size(75, 25)

$applyButton = New-Object System.Windows.Forms.Button
$applyButton.Text = 'Apply'
$applyButton.Location = New-Object System.Drawing.Point(300, 80)
$applyButton.Size = New-Object System.Drawing.Size(90, 30)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = 'Cancel'
$cancelButton.Location = New-Object System.Drawing.Point(405, 80)
$cancelButton.Size = New-Object System.Drawing.Size(90, 30)

$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = 'Images|*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.tif;*.tiff'
$dialog.Multiselect = $false

$browseButton.Add_Click({
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $pathBox.Text = $dialog.FileName
    }
})

$cancelButton.Add_Click({
    $form.Close()
})

$applyButton.Add_Click({
    $path = $pathBox.Text
    if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path)) {
        [System.Windows.Forms.MessageBox]::Show('Please select a valid image file.', 'Error', 'OK', 'Error') | Out-Null
        return
    }

    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value $path
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value 10
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value 0

    [WallpaperNative]::SystemParametersInfo(20, 0, $path, 3) | Out-Null
    $form.Close()
})

$form.Controls.AddRange(@($label, $pathBox, $browseButton, $applyButton, $cancelButton))
$form.ShowDialog() | Out-Null
