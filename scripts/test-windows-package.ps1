$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Dist = if ($env:HUHU_DIST) { $env:HUHU_DIST } else { Join-Path $Root 'dist' }
$InstallDir = Join-Path $env:TEMP 'Huhu install smoke'
$Installer = Join-Path $Dist 'Huhu-1.2.1-windows-x64-setup.exe'
$InstalledExe = Join-Path $InstallDir 'Huhu.exe'
$Registry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Huhu'
$Shortcut = Join-Path $env:APPDATA 'Microsoft/Windows/Start Menu/Programs/Huhu/Huhu.lnk'

# NSIS /D consumes the rest of the command line, including spaces.
$Install = Start-Process $Installer -ArgumentList "/S /D=$InstallDir" -Wait -PassThru
if ($Install.ExitCode -ne 0) { throw "Installer returned $($Install.ExitCode)" }
if (!(Test-Path $InstalledExe)) { throw 'Installed executable missing' }
if (!(Test-Path $Shortcut)) { throw 'Start Menu shortcut missing' }
if (!(Test-Path $Registry)) { throw 'Uninstall registry entry missing' }

$ValidationPath = Join-Path $Dist 'validation/windows-installed.json'
$Check = Start-Process $InstalledExe -ArgumentList '--self-test', "`"$ValidationPath`"" -Wait -PassThru
if ($Check.ExitCode -ne 0) { throw 'Installed executable failed artwork/gaze checks' }
$RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$ExpectedCommand = '"' + $InstalledExe + '"'
if ((Get-ItemProperty $RunKey -Name Huhu -ErrorAction SilentlyContinue).Huhu) { throw 'Startup should be off by default' }
$Enable = Start-Process $InstalledExe -ArgumentList '--startup-enable' -Wait -PassThru
if ($Enable.ExitCode -ne 0 -or (Get-ItemProperty $RunKey -Name Huhu).Huhu -ne $ExpectedCommand) { throw 'Startup enable or path quoting failed' }
$Disable = Start-Process $InstalledExe -ArgumentList '--startup-disable' -Wait -PassThru
if ($Disable.ExitCode -ne 0 -or (Get-ItemProperty $RunKey -Name Huhu -ErrorAction SilentlyContinue).Huhu) { throw 'Startup disable failed' }
$Enable = Start-Process $InstalledExe -ArgumentList '--startup-enable' -Wait -PassThru
if ($Enable.ExitCode -ne 0) { throw 'Startup re-enable failed' }
$Pet = Start-Process $InstalledExe -PassThru
try {
    Start-Sleep -Milliseconds 2000
    $Pet.Refresh()
    if ($Pet.HasExited) { throw "Companion exited at startup with code $($Pet.ExitCode)" }
} finally {
    if (!$Pet.HasExited) { Stop-Process -Id $Pet.Id -Force }
}

$Uninstall = Start-Process (Join-Path $InstallDir 'Uninstall.exe') -ArgumentList '/S' -Wait -PassThru
if ($Uninstall.ExitCode -ne 0) { throw "Uninstaller returned $($Uninstall.ExitCode)" }
for ($Attempt = 0; $Attempt -lt 20 -and (Test-Path $InstalledExe); $Attempt++) { Start-Sleep -Milliseconds 250 }
if (Test-Path $InstalledExe) { throw 'Uninstaller left the application executable' }
if (Test-Path $Shortcut) { throw 'Uninstaller left the shortcut' }
if (Test-Path $Registry) { throw 'Uninstaller left its registry entry' }
if ((Get-ItemProperty $RunKey -Name Huhu -ErrorAction SilentlyContinue).Huhu) { throw 'Uninstaller left its startup registration' }
@{
    ok = $true
    installerExitCode = $Install.ExitCode
    installedArtworkAndGaze = 'passed'
    companionStartup = 'passed'
    shortcut = 'verified'
    uninstallRegistry = 'verified'
    uninstallExitCode = $Uninstall.ExitCode
    uninstallCleanup = 'passed'
    startupEnableDisableAndUninstallCleanup = 'passed'
} | ConvertTo-Json | Set-Content (Join-Path $Dist 'validation/windows-installer.json')
Write-Host 'Install, installed app startup, artwork/gaze checks, and uninstall passed.'
