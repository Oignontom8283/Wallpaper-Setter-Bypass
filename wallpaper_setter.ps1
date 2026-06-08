param(
    [string]$Path,
    [ValidateSet("COM", "SPI", "Registry")]
    [string]$Method = "COM",
    [string]$Monitor    = "primary",   # COM only : primary | all | current | 0,1,2...
    [ValidateSet("Center","Tile","Stretch","Fit","Fill","Span")]
    [string]$Position   = "Fill",      # COM only
    [string]$BgColor    = "Black",     # COM only
    [ValidateSet("tile", "fullscreen")]
    [string]$DisplayMode = "fullscreen", # SPI + Registry
    [switch]$Stretch,                  # SPI only
    [switch]$Spanned,                  # SPI only
    [switch]$Help
)

# ==============================================================================
#  BOOTSTRAP
# ==============================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ── Native interop (shared by all methods) ─────────────────────────────────────
# Guard: only compile once per session (re-running the script in the same PS
# session would cause a "type already exists" compiler error otherwise).
if (-not ([System.Management.Automation.PSTypeName]'WallpaperNative').Type) {
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential)]
public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

[ComImport]
[Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IDesktopWallpaper {
    void SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID,
                      [MarshalAs(UnmanagedType.LPWStr)] string wallpaper);
    [return: MarshalAs(UnmanagedType.LPWStr)]
    string GetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID);
    [return: MarshalAs(UnmanagedType.LPWStr)]
    string GetMonitorDevicePathAt(uint monitorIndex);
    uint GetMonitorDevicePathCount();
    void GetMonitorRECT([MarshalAs(UnmanagedType.LPWStr)] string monitorID,
                        out RECT displayRect);
    void SetBackgroundColor(uint color);
    uint GetBackgroundColor();
    void SetPosition(uint position);
    uint GetPosition();
    void SetSlideshow(IntPtr items);
    IntPtr GetSlideshow();
    void SetSlideshowOptions(uint options, uint slideshowTick);
    void GetSlideshowOptions(out uint options, out uint slideshowTick);
    void AdvanceSlideshow([MarshalAs(UnmanagedType.LPWStr)] string monitorID,
                          uint direction);
    uint GetStatus();
    void Enable(bool enable);
}

[ComImport]
[Guid("C2CF3110-460E-4fc1-B9D0-8A1C0C9CC4BD")]
public class DesktopWallpaperCOM { }

public static class WallpaperNative {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam,
                                                   string lpvParam, int fuWinIni);

    private static IDesktopWallpaper GetCOM() {
        return (IDesktopWallpaper)new DesktopWallpaperCOM();
    }

    public static void COM_SetAll(string path) {
        IDesktopWallpaper dw = GetCOM();
        dw.SetWallpaper(null, path);
    }

    public static void COM_SetByRect(int left, int top, string path) {
        IDesktopWallpaper dw = GetCOM();
        uint n = dw.GetMonitorDevicePathCount();
        for (uint i = 0; i < n; i++) {
            string dev = dw.GetMonitorDevicePathAt(i);
            RECT r;
            dw.GetMonitorRECT(dev, out r);
            if (r.Left == left && r.Top == top) {
                dw.SetWallpaper(dev, path);
                return;
            }
        }
        if (n > 0) {
            dw.SetWallpaper(dw.GetMonitorDevicePathAt(0), path);
        }
    }

    public static void COM_SetByIndex(uint idx, string path) {
        IDesktopWallpaper dw = GetCOM();
        uint n = dw.GetMonitorDevicePathCount();
        if (idx < n) {
            dw.SetWallpaper(dw.GetMonitorDevicePathAt(idx), path);
        }
    }

    public static uint COM_MonitorCount() {
        IDesktopWallpaper dw = GetCOM();
        return dw.GetMonitorDevicePathCount();
    }

    // Position values: 0=Center, 1=Tile, 2=Stretch, 3=Fit, 4=Fill, 5=Span
    public static void COM_SetPosition(uint position) {
        IDesktopWallpaper dw = GetCOM();
        dw.SetPosition(position);
    }

    public static void COM_SetAllWithPosition(string path, uint position) {
        IDesktopWallpaper dw = GetCOM();
        dw.SetPosition(position);
        dw.SetWallpaper(null, path);
    }

    public static void COM_SetMonitorWithPosition(string devPath, string path, uint position) {
        IDesktopWallpaper dw = GetCOM();
        dw.SetPosition(position);
        dw.SetWallpaper(devPath, path);
    }

    // color: 0x00BBGGRR (Windows COLORREF)
    public static void COM_SetBackgroundColor(uint color) {
        IDesktopWallpaper dw = GetCOM();
        dw.SetBackgroundColor(color);
    }

    public static string COM_GetMonitorDevPath(int left, int top) {
        IDesktopWallpaper dw = GetCOM();
        uint n = dw.GetMonitorDevicePathCount();
        for (uint i = 0; i < n; i++) {
            string dev = dw.GetMonitorDevicePathAt(i);
            RECT r;
            dw.GetMonitorRECT(dev, out r);
            if (r.Left == left && r.Top == top) { return dev; }
        }
        if (n > 0) { return dw.GetMonitorDevicePathAt(0); }
        return null;
    }
}
'@
} # end guard

# ==============================================================================
#  UTILITIES
# ==============================================================================

function Write-Log {
    param([string]$Level, [string]$Message)
    $colors = @{ INFO='Cyan'; SUCCESS='Green'; WARNING='DarkYellow'; ERROR='Red'; DEBUG='Yellow' }
    $color = if ($colors.ContainsKey($Level)) { $colors[$Level] } else { 'White' }
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

function Test-ImageValid {
    param([string]$Path)
    try {
        $img = [System.Drawing.Image]::FromFile($Path)
        $img.Dispose()
        return $true
    } catch {
        return $false
    }
}

function Get-MonitorList {
    $screens = [System.Windows.Forms.Screen]::AllScreens
    $result  = @()

    # Try to enrich with WMI model names
    $nameMap = @{}
    try {
        foreach ($wm in (Get-WmiObject -Namespace root\wmi -Class WmiMonitorID -EA Stop | Where-Object Active)) {
            $n = -join ($wm.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
            if ($n) { $nameMap[($wm.InstanceName -split '\\')[1]] = $n.Trim() }
        }
    } catch {}

    for ($i = 0; $i -lt $screens.Count; $i++) {
        $s    = $screens[$i]
        $dev  = $s.DeviceName -replace '\\\\.\\',''
        $label= if ($s.Primary) { "$dev (Primary)" } else { "$dev (Monitor $($i+1))" }
        foreach ($k in $nameMap.Keys) {
            if ($dev -like "*$k*" -or $k -like "*$dev*") { $label += " — $($nameMap[$k])"; break }
        }
        $result += [PSCustomObject]@{ Index=$i; Name=$label; IsPrimary=$s.Primary; Screen=$s }
    }
    return ,$result
}

# ==============================================================================
#  METHOD REGISTRY  — add new methods HERE only
#
#  Each entry must expose:
#    Name        [string]   Display name shown in GUI radio-buttons
#    Description [string]   Short tooltip description
#    Apply       [scriptblock]  { param($Path, $Params) ... return $true/$false }
#    Params      [hashtable] param descriptors consumed by GUI/CLI
#                  Each param: @{ Label; Type; Default; Choices (opt); CLIName }
# ==============================================================================

$WallpaperMethods = [ordered]@{

    # ── COM (IDesktopWallpaper) ──────────────────────────────────────────────
    COM = @{
        Name        = "COM — IDesktopWallpaper"
        Description = "Uses the Windows Shell COM interface. Per-monitor support, position styles, background color. Most reliable on modern Windows."
        Params      = [ordered]@{
            Monitor = @{
                Label   = "Monitor"
                Type    = "Combo"
                Default = "primary"
                Choices = @("current","primary","all")
                CLIName = "Monitor"
                Tooltip = "Target monitor(s) for the wallpaper"
            }
            Position = @{
                Label   = "Position"
                Type    = "Radio"
                Default = "Fill"
                Choices = @("Center","Tile","Stretch","Fit","Fill","Span")
                CLIName = "Position"
                Tooltip = "Center: centered · Tile: repeated · Stretch: distorted fill · Fit: letterboxed · Fill: cropped fill · Span: across all monitors"
            }
            BgColor = @{
                Label   = "Background color"
                Type    = "Combo"
                Default = "Black"
                Choices = @("Black","White","Gray","Dark Gray","Navy","Dark Green","Maroon","Custom…")
                CLIName = "BgColor"
                Tooltip = "Color shown behind the wallpaper when it does not cover the full screen"
            }
        }
        Apply = {
            param([string]$Path, [hashtable]$Params)
            $mon      = $Params.Monitor
            $position = $Params.Position
            $bgColor  = $Params.BgColor

            # Map position name to COM uint value
            $posMap = @{ Center=0; Tile=1; Stretch=2; Fit=3; Fill=4; Span=5 }
            $posVal = if ($posMap.ContainsKey($position)) { [uint32]$posMap[$position] } else { [uint32]4 }

            # Map color name to COLORREF (0x00BBGGRR)
            $colorMap = @{
                'Black'     = [uint32]0x00000000
                'White'     = [uint32]0x00FFFFFF
                'Gray'      = [uint32]0x00808080
                'Dark Gray' = [uint32]0x00404040
                'Navy'      = [uint32]0x00800000   # COLORREF is BGR
                'Dark Green'= [uint32]0x00008000
                'Maroon'    = [uint32]0x00000080
            }
            $colorVal = if ($bgColor -like 'Custom:#*') {
                # Parse #RRGGBB → COLORREF 0x00BBGGRR
                $hex = $bgColor -replace 'Custom:#',''
                $r = [Convert]::ToUInt32($hex.Substring(0,2), 16)
                $g = [Convert]::ToUInt32($hex.Substring(2,2), 16)
                $b = [Convert]::ToUInt32($hex.Substring(4,2), 16)
                [uint32](($b -shl 16) -bor ($g -shl 8) -bor $r)
            } elseif ($colorMap.ContainsKey($bgColor)) {
                $colorMap[$bgColor]
            } else {
                [uint32]0
            }

            Write-Log INFO "COM method — monitor:$mon position:$position($posVal) bg:$bgColor"
            try {
                [WallpaperNative]::COM_SetBackgroundColor($colorVal)

                if ($mon -eq "all" -or $position -eq "Span") {
                    [WallpaperNative]::COM_SetAllWithPosition($Path, $posVal)
                } else {
                    $target = $null
                    if ($mon -eq "primary") {
                        $target = [System.Windows.Forms.Screen]::PrimaryScreen
                    } elseif ($mon -eq "current") {
                        $target = [System.Windows.Forms.Screen]::PrimaryScreen
                    } elseif ($mon -match '^\d+$') {
                        $idx = [int]$mon
                        $all = [System.Windows.Forms.Screen]::AllScreens
                        if ($idx -lt $all.Count) { $target = $all[$idx] }
                    } else {
                        foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
                            if ($s.DeviceName -eq $mon) { $target = $s; break }
                        }
                    }

                    if ($target) {
                        $devPath = [WallpaperNative]::COM_GetMonitorDevPath($target.Bounds.Left, $target.Bounds.Top)
                        if ($devPath) {
                            [WallpaperNative]::COM_SetMonitorWithPosition($devPath, $Path, $posVal)
                        } else {
                            Write-Log WARNING "Could not resolve monitor device path, applying to all"
                            [WallpaperNative]::COM_SetAllWithPosition($Path, $posVal)
                        }
                    } else {
                        Write-Log WARNING "Monitor '$mon' not found — applying to all"
                        [WallpaperNative]::COM_SetAllWithPosition($Path, $posVal)
                    }
                }
                Write-Log SUCCESS "COM method succeeded"
                return $true
            } catch {
                Write-Log ERROR "COM method failed: $($_.Exception.Message)"
                return $false
            }
        }
    }

    # ── SPI (SystemParametersInfo) ───────────────────────────────────────────
    SPI = @{
        Name        = "SPI — SystemParametersInfo"
        Description = "Classic Win32 API call. Applies globally (all monitors). Supports tile and fullscreen styles."
        Params      = [ordered]@{
            DisplayMode = @{
                Label   = "Display mode"
                Type    = "Radio"
                Default = "fullscreen"
                Choices = @("fullscreen","tile")
                CLIName = "DisplayMode"
                Tooltip = "fullscreen: centered/stretched · tile: repeated"
            }
            Stretch = @{
                Label   = "Stretch to fill"
                Type    = "Check"
                Default = $true
                CLIName = "Stretch"
                Tooltip = "Stretch image to fill screen (fullscreen mode only)"
                EnabledWhen = @{ DisplayMode = "fullscreen" }
            }
            Spanned = @{
                Label   = "Span across all monitors"
                Type    = "Check"
                Default = $false
                CLIName = "Spanned"
                Tooltip = "Treat all monitors as one wide canvas"
            }
        }
        Apply = {
            param([string]$Path, [hashtable]$Params)
            $mode    = $Params.DisplayMode
            $stretch = [bool]$Params.Stretch
            $spanned = [bool]$Params.Spanned
            Write-Log INFO "SPI method — mode:$mode stretch:$stretch spanned:$spanned"

            try {
                $regPath = 'HKCU:\Control Panel\Desktop'

                if ($spanned) {
                    Set-ItemProperty $regPath WallpaperStyle 22
                    Set-ItemProperty $regPath TileWallpaper  0
                } elseif ($mode -eq "tile") {
                    Set-ItemProperty $regPath WallpaperStyle 1
                    Set-ItemProperty $regPath TileWallpaper  1
                } elseif ($stretch) {
                    Set-ItemProperty $regPath WallpaperStyle 2
                    Set-ItemProperty $regPath TileWallpaper  0
                } else {
                    Set-ItemProperty $regPath WallpaperStyle 6
                    Set-ItemProperty $regPath TileWallpaper  0
                }

                Set-ItemProperty $regPath Wallpaper $Path
                [WallpaperNative]::SystemParametersInfo(20, 0, $Path, 3) | Out-Null
                Write-Log SUCCESS "SPI method succeeded"
                return $true
            } catch {
                Write-Log ERROR "SPI method failed: $($_.Exception.Message)"
                return $false
            }
        }
    }

    # ── Registry (direct write + SPI refresh) ────────────────────────────────
    Registry = @{
        Name        = "Registry — Direct write"
        Description = "Writes directly to HKCU\Control Panel\Desktop then forces a desktop refresh. May bypass some restrictions."
        Params      = [ordered]@{
            DisplayMode = @{
                Label   = "Display mode"
                Type    = "Radio"
                Default = "fullscreen"
                Choices = @("fullscreen","tile")
                CLIName = "DisplayMode"
                Tooltip = "fullscreen (WallpaperStyle=6) or tile (WallpaperStyle=1)"
            }
        }
        Apply = {
            param([string]$Path, [hashtable]$Params)
            $mode = $Params.DisplayMode
            Write-Log INFO "Registry method — mode:$mode"
            try {
                $regPath = 'HKCU:\Control Panel\Desktop'
                Set-ItemProperty $regPath Wallpaper $Path -EA Stop
                if ($mode -eq "tile") {
                    Set-ItemProperty $regPath WallpaperStyle 1
                    Set-ItemProperty $regPath TileWallpaper  1
                } else {
                    Set-ItemProperty $regPath WallpaperStyle 6
                    Set-ItemProperty $regPath TileWallpaper  0
                }
                [WallpaperNative]::SystemParametersInfo(20, 0, $Path, 3) | Out-Null
                Write-Log SUCCESS "Registry method succeeded"
                return $true
            } catch {
                Write-Log ERROR "Registry method failed: $($_.Exception.Message)"
                return $false
            }
        }
    }

    # ── TEMPLATE — copy/rename to add a new method ───────────────────────────
    # NewMethod = @{
    #     Name        = "NewMethod — Display name"
    #     Description = "Short description shown in GUI."
    #     Params      = [ordered]@{
    #         SomeParam = @{
    #             Label   = "Param label"
    #             Type    = "Radio|Check|Combo|Text"
    #             Default = "defaultValue"
    #             Choices = @("a","b")   # for Radio/Combo only
    #             CLIName = "SomeParam"
    #             Tooltip = "Tooltip text"
    #         }
    #     }
    #     Apply = {
    #         param([string]$Path, [hashtable]$Params)
    #         # ... your logic ...
    #         return $true  # or $false
    #     }
    # }
}

# ==============================================================================
#  APPLY DISPATCHER  (validates image, dispatches to chosen method)
# ==============================================================================

function Invoke-SetWallpaper {
    param(
        [string]$Path,
        [string]$MethodKey,
        [hashtable]$Params,
        [bool]$IsGUI = $false
    )

    # Validate path
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        Write-Log ERROR "Invalid or missing image path: '$Path'"
        return $false
    }
    if (-not (Test-ImageValid $Path)) {
        Write-Log ERROR "File is not a valid image: '$Path'"
        return $false
    }

    $methodDef = $WallpaperMethods[$MethodKey]
    if (-not $methodDef) {
        Write-Log ERROR "Unknown method: '$MethodKey'"
        return $false
    }

    Write-Log INFO "=== Applying wallpaper via $($methodDef.Name) ==="
    $result = & $methodDef.Apply $Path $Params
    return $result
}

# ==============================================================================
#  HELP
# ==============================================================================

if ($Help) {
    Write-Host @"

Wallpaper Setter — PowerShell

USAGE
  .\wallpaper_setter.ps1 [OPTIONS]
  .\wallpaper_setter.ps1              → opens the GUI

COMMON OPTIONS
  -Path <path>          Image file to set as wallpaper (enables CLI mode)
  -Method <key>         Method: COM (default) | SPI | Registry
  -Help                 Show this help

METHOD-SPECIFIC OPTIONS

  COM   (default, per-monitor)
    -Monitor <value>    primary (default) | all | current | 0 | 1 | 2 …
    -Position <value>   Center | Tile | Stretch | Fit | Fill (default) | Span
    -BgColor <value>    Black (default) | White | Gray | Dark Gray | Navy | Dark Green | Maroon

  SPI   (global, classic Win32)
    -DisplayMode        fullscreen (default) | tile
    -Stretch            Stretch to fill (fullscreen only)
    -Spanned            Span across all monitors

  Registry  (direct HKCU write)
    -DisplayMode        fullscreen (default) | tile

EXAMPLES
  # GUI
  .\wallpaper_setter.ps1

  # COM — set on monitor index 1
  .\wallpaper_setter.ps1 -Path "C:\img.jpg" -Method COM -Monitor 1

  # SPI — tile on all monitors
  .\wallpaper_setter.ps1 -Path "C:\img.jpg" -Method SPI -DisplayMode tile

  # Registry fallback
  .\wallpaper_setter.ps1 -Path "C:\img.jpg" -Method Registry

"@
    exit
}

# ==============================================================================
#  CLI MODE
# ==============================================================================

if (-not [string]::IsNullOrWhiteSpace($Path)) {
    Write-Log INFO "=== Wallpaper Setter — CLI Mode ==="

    # Build param hashtable from CLI switches based on the chosen method
    $methodDef = $WallpaperMethods[$Method]
    if (-not $methodDef) {
        Write-Log ERROR "Unknown method '$Method'. Valid: $($WallpaperMethods.Keys -join ', ')"
        exit 1
    }

    $cliParams = @{}
    foreach ($pKey in $methodDef.Params.Keys) {
        $pDef  = $methodDef.Params[$pKey]
        $cliName = $pDef.CLIName
        $val   = $null

        # Check if the corresponding script parameter was supplied
        switch ($cliName) {
            "Monitor"     { $val = $Monitor }
            "Position"    { $val = $Position }
            "BgColor"     { $val = $BgColor }
            "DisplayMode" { $val = $DisplayMode }
            "Stretch"     { $val = $Stretch.IsPresent }
            "Spanned"     { $val = $Spanned.IsPresent }
            default       { $val = $pDef.Default }
        }
        $cliParams[$pKey] = if ($null -ne $val) { $val } else { $pDef.Default }
    }

    $ok = Invoke-SetWallpaper -Path $Path -MethodKey $Method -Params $cliParams -IsGUI $false

    if ($ok) {
        [System.Windows.Forms.MessageBox]::Show(
            "Wallpaper applied successfully!",
            "Success",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to apply wallpaper. Check the console for details.",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    exit
}

# ==============================================================================
#  GUI MODE
# ==============================================================================

[System.Windows.Forms.Application]::EnableVisualStyles()

$monitors = Get-MonitorList

# ── Dimensions ────────────────────────────────────────────────────────────────
$formW   = 820
$formH   = 480
$leftW   = 420   # left panel width
$previewX= $leftW + 10
$previewW= $formW - $previewX - 20

# ── Form ──────────────────────────────────────────────────────────────────────
$form = New-Object System.Windows.Forms.Form
$form.Text            = "Wallpaper Setter"
$form.Size            = New-Object System.Drawing.Size($formW, $formH)
$form.StartPosition   = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox     = $false

$tooltip = New-Object System.Windows.Forms.ToolTip
$tooltip.AutoPopDelay = 6000
$tooltip.InitialDelay = 400

# ── File picker row ───────────────────────────────────────────────────────────
$fileLabel = New-Object System.Windows.Forms.Label
$fileLabel.Text     = "Image:"
$fileLabel.AutoSize = $true
$fileLabel.Location = New-Object System.Drawing.Point(12, 18)

$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.Location = New-Object System.Drawing.Point(60, 14)
$pathBox.Size     = New-Object System.Drawing.Size(260, 22)
$pathBox.ReadOnly = $true

$browseBtn = New-Object System.Windows.Forms.Button
$browseBtn.Text     = "Browse…"
$browseBtn.Location = New-Object System.Drawing.Point(328, 13)
$browseBtn.Size     = New-Object System.Drawing.Size(80, 25)
$tooltip.SetToolTip($browseBtn, "Select an image file (jpg, png, bmp, gif, tiff)")

# ── Method selector (radio buttons) ───────────────────────────────────────────
$methodGroup = New-Object System.Windows.Forms.GroupBox
$methodGroup.Text     = "Method"
$methodGroup.Location = New-Object System.Drawing.Point(12, 48)
$methodGroup.Size     = New-Object System.Drawing.Size($($leftW - 24), 60)

$methodRadios = [ordered]@{}
$mx = 10
foreach ($mKey in $WallpaperMethods.Keys) {
    $rb = New-Object System.Windows.Forms.RadioButton
    $rb.Text     = $mKey
    $rb.Tag      = $mKey
    $rb.AutoSize = $true
    $rb.Location = New-Object System.Drawing.Point($mx, 24)
    $tooltip.SetToolTip($rb, $WallpaperMethods[$mKey].Description)
    $methodGroup.Controls.Add($rb)
    $methodRadios[$mKey] = $rb
    $mx += 130
}
$methodRadios["COM"].Checked = $true

# ── Params panel (dynamic, per method) ────────────────────────────────────────
$paramsGroup = New-Object System.Windows.Forms.GroupBox
$paramsGroup.Text     = "Options"
$paramsGroup.Location = New-Object System.Drawing.Point(12, 118)
$paramsGroup.Size     = New-Object System.Drawing.Size($($leftW - 24), 290)

# Outer scrollable panel — fixed size, clips overflow
$paramsScroll = New-Object System.Windows.Forms.Panel
$paramsScroll.Location   = New-Object System.Drawing.Point(4, 18)
$paramsScroll.Size       = New-Object System.Drawing.Size($($leftW - 24 - 8), 266)
$paramsScroll.AutoScroll = $true
$paramsGroup.Controls.Add($paramsScroll)

# Inner panel — grows to fit content, triggers scroll in outer panel
$paramsInner = New-Object System.Windows.Forms.Panel
$paramsInner.Location = New-Object System.Drawing.Point(0, 0)
$paramsInner.Width    = $paramsScroll.Width - 20   # leave room for scrollbar
$paramsInner.Height   = 10  # will be set dynamically after content is built
$paramsScroll.Controls.Add($paramsInner)

# ── Preview box ───────────────────────────────────────────────────────────────
$previewBox = New-Object System.Windows.Forms.PictureBox
$previewBox.Location  = New-Object System.Drawing.Point($previewX, 14)
$previewBox.Size      = New-Object System.Drawing.Size($previewW, 410)
$previewBox.BorderStyle = 'FixedSingle'
$previewBox.SizeMode  = 'Zoom'
$previewBox.BackColor = [System.Drawing.Color]::FromArgb(220,220,220)
$tooltip.SetToolTip($previewBox, "Preview of selected image")

# ── Action buttons ────────────────────────────────────────────────────────────
$applyBtn = New-Object System.Windows.Forms.Button
$applyBtn.Text     = "Apply"
$applyBtn.Location = New-Object System.Drawing.Point(12, 420)
$applyBtn.Size     = New-Object System.Drawing.Size(100, 30)
$tooltip.SetToolTip($applyBtn, "Apply the wallpaper with the chosen settings")

$exitBtn = New-Object System.Windows.Forms.Button
$exitBtn.Text     = "Exit"
$exitBtn.Location = New-Object System.Drawing.Point(122, 420)
$exitBtn.Size     = New-Object System.Drawing.Size(100, 30)
$tooltip.SetToolTip($exitBtn, "Close without applying")

# ── Control state store (key = methodKey.paramKey) ───────────────────────────
$controlStore = @{}   # stores live WinForms controls keyed by "METHOD.PARAM"

# ── Build params panel for a given method ─────────────────────────────────────
function Update-ParamsPanel {
    param([string]$MethodKey)

    $paramsInner.Controls.Clear()
    $controlStore.Clear()

    $methodDef = $WallpaperMethods[$MethodKey]
    if (-not $methodDef) { return }

    $y = 6

    foreach ($pKey in $methodDef.Params.Keys) {
        $pDef = $methodDef.Params[$pKey]

        switch ($pDef.Type) {

            "Radio" {
                $lbl = New-Object System.Windows.Forms.Label
                $lbl.Text     = $pDef.Label + ":"
                $lbl.AutoSize = $true
                $lbl.Location = New-Object System.Drawing.Point(10, $y)
                $paramsInner.Controls.Add($lbl)
                $y += 22

                $radioGroup = @{}
                foreach ($choice in $pDef.Choices) {
                    $rb = New-Object System.Windows.Forms.RadioButton
                    $rb.Text     = $choice
                    $rb.Tag      = $choice
                    $rb.AutoSize = $true
                    $rb.Location = New-Object System.Drawing.Point(20, $y)
                    $rb.Checked  = ($choice -eq $pDef.Default)
                    $tooltip.SetToolTip($rb, $pDef.Tooltip)
                    $paramsInner.Controls.Add($rb)
                    $radioGroup[$choice] = $rb
                    $y += 22
                }
                $controlStore["$MethodKey.$pKey"] = $radioGroup
            }

            "Check" {
                $cb = New-Object System.Windows.Forms.CheckBox
                $cb.Text     = $pDef.Label
                $cb.Checked  = [bool]$pDef.Default
                $cb.AutoSize = $true
                $cb.Location = New-Object System.Drawing.Point(10, $y)
                $tooltip.SetToolTip($cb, $pDef.Tooltip)
                $paramsInner.Controls.Add($cb)
                $controlStore["$MethodKey.$pKey"] = $cb

                # Wire EnabledWhen dependency
                if ($pDef.EnabledWhen) {
                    $depParam = ($pDef.EnabledWhen.GetEnumerator() | Select-Object -First 1)
                    $depKey   = $depParam.Key
                    $depVal   = $depParam.Value
                    $targetCB = $cb

                    $updateEnabled = {
                        $radioMap = $controlStore["$MethodKey.$depKey"]
                        if ($radioMap -and $radioMap[$depVal]) {
                            $targetCB.Enabled = $radioMap[$depVal].Checked
                        }
                    }
                    $script:EnabledWhenJobs += @{ Action=$updateEnabled; RadioKey="$MethodKey.$depKey"; DepVal=$depVal; Target=$targetCB }
                }
                $y += 26
            }

            "Combo" {
                $lbl = New-Object System.Windows.Forms.Label
                $lbl.Text     = $pDef.Label + ":"
                $lbl.AutoSize = $true
                $lbl.Location = New-Object System.Drawing.Point(10, $y)
                $paramsInner.Controls.Add($lbl)
                $y += 22

                $cb = New-Object System.Windows.Forms.ComboBox
                $cb.Location      = New-Object System.Drawing.Point(20, $y)
                $cb.Size          = New-Object System.Drawing.Size(200, 22)
                $cb.DropDownStyle = 'DropDownList'
                $tooltip.SetToolTip($cb, $pDef.Tooltip)

                foreach ($c in $pDef.Choices) { [void]$cb.Items.Add($c) }

                if ($pKey -eq "Monitor") {
                    foreach ($m in $monitors) { [void]$cb.Items.Add($m.Name) }
                }

                $def = $pDef.Default
                $idx = $cb.Items.IndexOf($def)
                $cb.SelectedIndex = if ($idx -ge 0) { $idx } else { 0 }

                if ($pKey -eq "BgColor") {
                    $colorSwatch = New-Object System.Windows.Forms.Panel
                    $colorSwatch.Location    = New-Object System.Drawing.Point(228, $($y + 2))
                    $colorSwatch.Size        = New-Object System.Drawing.Size(18, 18)
                    $colorSwatch.BorderStyle = 'FixedSingle'
                    $colorSwatch.BackColor   = [System.Drawing.Color]::Black
                    $paramsInner.Controls.Add($colorSwatch)

                    $script:CustomColor    = [System.Drawing.Color]::Black
                    $script:ColorSwatchCtl = $colorSwatch   # script-scope ref, survives panel rebuild

                    $cb.Add_SelectedIndexChanged({
                        $sender = $args[0]
                        if ($null -eq $sender -or $sender.SelectedIndex -lt 0 -or $null -eq $sender.SelectedItem) { return }
                        $sel = $sender.SelectedItem.ToString()
                        if ([string]::IsNullOrEmpty($sel)) { return }
                        $swatch = $script:ColorSwatchCtl
                        if ($null -eq $swatch -or $swatch.IsDisposed) { return }
                        $namedMap = @{
                            'Black'     = [System.Drawing.Color]::Black
                            'White'     = [System.Drawing.Color]::White
                            'Gray'      = [System.Drawing.Color]::Gray
                            'Dark Gray' = [System.Drawing.Color]::FromArgb(64,64,64)
                            'Navy'      = [System.Drawing.Color]::Navy
                            'Dark Green'= [System.Drawing.Color]::DarkGreen
                            'Maroon'    = [System.Drawing.Color]::Maroon
                        }
                        if ($sel -eq 'Custom…') {
                            $cd = New-Object System.Windows.Forms.ColorDialog
                            $cd.Color    = $script:CustomColor
                            $cd.FullOpen = $true
                            if ($cd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                                $script:CustomColor = $cd.Color
                                $swatch.BackColor   = $cd.Color
                            } else {
                                $sender.SelectedIndex = 0
                            }
                            $cd.Dispose()
                        } elseif ($namedMap.ContainsKey($sel)) {
                            $swatch.BackColor = $namedMap[$sel]
                        }
                    })
                }

                $paramsInner.Controls.Add($cb)
                $controlStore["$MethodKey.$pKey"] = $cb
                $y += 28
            }

            "Text" {
                $lbl = New-Object System.Windows.Forms.Label
                $lbl.Text     = $pDef.Label + ":"
                $lbl.AutoSize = $true
                $lbl.Location = New-Object System.Drawing.Point(10, $y)
                $paramsInner.Controls.Add($lbl)
                $y += 22

                $tb = New-Object System.Windows.Forms.TextBox
                $tb.Text     = $pDef.Default
                $tb.Location = New-Object System.Drawing.Point(20, $y)
                $tb.Size     = New-Object System.Drawing.Size(200, 22)
                $tooltip.SetToolTip($tb, $pDef.Tooltip)
                $paramsInner.Controls.Add($tb)
                $controlStore["$MethodKey.$pKey"] = $tb
                $y += 28
            }
        }
    }

    # Deferred wire-up for EnabledWhen
    foreach ($job in $script:EnabledWhenJobs) {
        $radioMap = $controlStore[$job.RadioKey]
        if ($radioMap) {
            $sb = [scriptblock]$job.Action
            foreach ($rb in $radioMap.Values) {
                $capturedSb = $sb
                $rb.Add_CheckedChanged($capturedSb)
            }
            & $sb  # initial state
        }
    }

    # Set inner panel height so the outer panel scrolls correctly
    $paramsInner.Height = [Math]::Max($y + 10, $paramsScroll.Height)
    # Reset scroll to top
    $paramsScroll.AutoScrollPosition = New-Object System.Drawing.Point(0, 0)
}

# ── Read current GUI param values for a method ────────────────────────────────
function Get-GUIParams {
    param([string]$MethodKey)

    $methodDef = $WallpaperMethods[$MethodKey]
    $result    = @{}

    foreach ($pKey in $methodDef.Params.Keys) {
        $pDef   = $methodDef.Params[$pKey]
        $ctlKey = "$MethodKey.$pKey"

        switch ($pDef.Type) {
            "Radio" {
                $radioMap = $controlStore[$ctlKey]
                $selected = $pDef.Default
                if ($radioMap) {
                    foreach ($kv in $radioMap.GetEnumerator()) {
                        if ($kv.Value.Checked) { $selected = $kv.Key; break }
                    }
                }
                $result[$pKey] = $selected
            }
            "Check" {
                $ctl = $controlStore[$ctlKey]
                $result[$pKey] = if ($ctl) { $ctl.Checked } else { [bool]$pDef.Default }
            }
            "Combo" {
                $ctl = $controlStore[$ctlKey]
                if ($ctl -and $ctl.SelectedItem) {
                    $val = $ctl.SelectedItem.ToString()
                    # Resolve named monitor to DeviceName
                    if ($pKey -eq "Monitor") {
                        $lower = $val.ToLower()
                        if ($lower -notin @("primary","all","current")) {
                            if ($lower -match '^\d+$') {
                                # numeric index — keep as-is
                            } else {
                                # named monitor from list
                                foreach ($m in $monitors) {
                                    if ($m.Name -eq $val) { $val = $m.Screen.DeviceName; break }
                                }
                                # "current" = form center screen
                                if ($val -eq "current") {
                                    $cx = $form.Location.X + $form.Width  / 2
                                    $cy = $form.Location.Y + $form.Height / 2
                                    $val = [System.Windows.Forms.Screen]::FromPoint(
                                        [System.Drawing.Point]::new($cx,$cy)).DeviceName
                                }
                            }
                        }
                    }
                    # Resolve "Custom…" to the hex color string for the Apply scriptblock
                    if ($pKey -eq "BgColor" -and $val -eq 'Custom…') {
                        $c = $script:CustomColor
                        $val = "Custom:#$($c.R.ToString('X2'))$($c.G.ToString('X2'))$($c.B.ToString('X2'))"
                    }
                    $result[$pKey] = $val
                } else {
                    $result[$pKey] = $pDef.Default
                }
            }
            "Text" {
                $ctl = $controlStore[$ctlKey]
                $result[$pKey] = if ($ctl) { $ctl.Text } else { $pDef.Default }
            }
        }
    }
    return $result
}

# ── Wire method radio buttons ─────────────────────────────────────────────────
foreach ($mKey in $methodRadios.Keys) {
    $rb = $methodRadios[$mKey]
    $rb.Add_CheckedChanged({
        $sender = $args[0]
        if ($sender.Checked) {
            $script:EnabledWhenJobs = @()
            Update-ParamsPanel -MethodKey $sender.Tag
        }
    })
}

# ── Browse button ─────────────────────────────────────────────────────────────
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = 'Images|*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.tif;*.tiff'

$browseBtn.Add_Click({
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $pathBox.Text = $dialog.FileName
        try {
            if ($previewBox.Image) { $previewBox.Image.Dispose(); $previewBox.Image = $null }
            $previewBox.Image = [System.Drawing.Image]::FromFile($dialog.FileName)
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Could not load image preview.",
                "Warning",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
    }
})

# ── Apply button ──────────────────────────────────────────────────────────────
$applyBtn.Add_Click({
    $activeMethod = ($methodRadios.GetEnumerator() | Where-Object { $_.Value.Checked } | Select-Object -First 1).Key
    if (-not $activeMethod) { return }

    $guiParams = Get-GUIParams -MethodKey $activeMethod
    $ok = Invoke-SetWallpaper -Path $pathBox.Text -MethodKey $activeMethod -Params $guiParams -IsGUI $true

    if ($ok) {
        [System.Windows.Forms.MessageBox]::Show(
            "Wallpaper applied successfully!",
            "Success",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to apply wallpaper.`nCheck the console for details.",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

$exitBtn.Add_Click({ $form.Close() })
$form.Add_FormClosed({ $dialog.Dispose() })

# ── Assemble form ─────────────────────────────────────────────────────────────
$form.Controls.AddRange(@(
    $fileLabel, $pathBox, $browseBtn,
    $methodGroup, $paramsGroup,
    $previewBox, $applyBtn, $exitBtn
))

# Initial panel render
$script:EnabledWhenJobs = @()
Update-ParamsPanel -MethodKey "COM"

$form.ShowDialog() | Out-Null