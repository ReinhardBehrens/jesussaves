# SPDX-License-Identifier: GPL-3.0-only
[CmdletBinding()]
param(
    [ValidateRange(1, 9999)][int]$Minutes = 5,
    [switch]$NoSettings
)
$ErrorActionPreference = 'Stop'
$destination = Join-Path $env:LOCALAPPDATA 'JesusSaves'
$desktopKey = 'HKCU:\Control Panel\Desktop'
$files = @('JesusSaves.exe', 'JesusSaves.scr', 'SDL2.dll', 'LICENSE',
    'SDL2-LICENSE.txt', 'README-Windows.md', 'install.cmd', 'install.ps1', 'licenses\DejaVu.txt')
foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $file) -PathType Leaf)) {
        throw "Missing $file. Extract the entire ZIP before running install.cmd."
    }
}
# Do not overwrite centrally managed screensaver choices.
foreach ($hive in @('HKCU:', 'HKLM:')) {
    $policy = Get-ItemProperty "$hive\Software\Policies\Microsoft\Windows\Control Panel\Desktop" -ErrorAction SilentlyContinue
    foreach ($name in @('SCRNSAVE.EXE', 'ScreenSaveActive', 'ScreenSaveTimeOut')) {
        if ($policy -and $policy.PSObject.Properties[$name]) {
            throw "Your organization manages $name. Contact its administrator to select Jesus Saves."
        }
    }
}
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class JesusSavesInstallerApi {
    [DllImport("user32.dll", EntryPoint="SystemParametersInfoW", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool Set(uint action, uint value, IntPtr unused, uint flags);
    [DllImport("user32.dll", EntryPoint="SystemParametersInfoW", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool Get(uint action, uint unused, out uint value, uint flags);
}
'@
function Set-SaverParameter([uint32]$Action, [uint32]$Value) {
    # Update both the saved preference and the live Windows session; notify apps.
    if (-not [JesusSavesInstallerApi]::Set($Action, $Value, [IntPtr]::Zero, 3)) {
        throw [ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
}
[uint32]$oldActive = 0; [uint32]$oldTimeout = 0
if (-not [JesusSavesInstallerApi]::Get(0x10, 0, [ref]$oldActive, 0) -or
    -not [JesusSavesInstallerApi]::Get(0x0E, 0, [ref]$oldTimeout, 0)) {
    throw 'Cannot read the current Windows screensaver settings.'
}
$previous = Get-ItemProperty $desktopKey
$oldSaver = $previous.PSObject.Properties['SCRNSAVE.EXE']
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$backup = Join-Path $destination 'previous-screensaver.json'
if (-not (Test-Path -LiteralPath $backup)) {
    @{ Saver = $(if ($oldSaver) { $oldSaver.Value } else { $null }); Active = $oldActive; Timeout = $oldTimeout } |
        ConvertTo-Json | Set-Content -LiteralPath $backup -Encoding UTF8
}
foreach ($file in $files) {
    $source = Join-Path $PSScriptRoot $file
    $target = Join-Path $destination $file
    New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
    if ([IO.Path]::GetFullPath($source) -ne [IO.Path]::GetFullPath($target)) {
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}
$saver = Join-Path $destination 'JesusSaves.scr'
try {
    New-ItemProperty $desktopKey -Name 'SCRNSAVE.EXE' -Value $saver -PropertyType String -Force | Out-Null
    Set-SaverParameter 0x0F ($Minutes * 60) # SPI_SETSCREENSAVETIMEOUT
    Set-SaverParameter 0x11 1               # SPI_SETSCREENSAVEACTIVE
    [uint32]$active = 0; [uint32]$timeout = 0
    if (-not [JesusSavesInstallerApi]::Get(0x10, 0, [ref]$active, 0) -or
        -not [JesusSavesInstallerApi]::Get(0x0E, 0, [ref]$timeout, 0) -or
        $active -ne 1 -or $timeout -ne ($Minutes * 60) -or
        (Get-ItemPropertyValue $desktopKey 'SCRNSAVE.EXE') -ne $saver) {
        throw 'Windows did not retain the selected screensaver and timeout.'
    }
} catch {
    if ($oldSaver) {
        New-ItemProperty $desktopKey -Name 'SCRNSAVE.EXE' -Value $oldSaver.Value -PropertyType String -Force | Out-Null
    } else {
        Remove-ItemProperty $desktopKey 'SCRNSAVE.EXE' -ErrorAction SilentlyContinue
    }
    Set-SaverParameter 0x0F $oldTimeout
    Set-SaverParameter 0x11 $oldActive
    throw
}
Write-Host "Installed and selected Jesus Saves. Starts after $Minutes minutes of inactivity."
Write-Host 'Your existing sign-in requirement has not been changed.'
if (-not $NoSettings) {
    Start-Process "$env:SystemRoot\System32\rundll32.exe" -ArgumentList 'shell32.dll,Control_RunDLL desk.cpl,,1'
}
