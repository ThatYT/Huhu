$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Dist = if ($env:HUHU_DIST) { $env:HUHU_DIST } else { Join-Path $Root 'dist' }
New-Item -ItemType Directory -Force "$Dist/windows-x64", "$Dist/validation" | Out-Null
Push-Location "$Root/windows"
try {
    & rc.exe /nologo /fo "$Dist/windows-x64/Huhu.res" Huhu.rc
    if ($LASTEXITCODE -ne 0) { throw 'Resource compilation failed' }
    & cl.exe /nologo /utf-8 /O2 /EHsc /std:c++17 /MT Huhu.cpp "$Dist/windows-x64/Huhu.res" "/Fe:$Dist/windows-x64/Huhu.exe" "/Fo:$Dist/windows-x64/Huhu.obj" /link /SUBSYSTEM:WINDOWS gdiplus.lib ole32.lib shlwapi.lib shell32.lib user32.lib gdi32.lib advapi32.lib
    if ($LASTEXITCODE -ne 0) { throw 'Windows compilation failed' }
    $Test = Start-Process "$Dist/windows-x64/Huhu.exe" -ArgumentList '--self-test', "`"$Dist/validation/windows.json`"" -Wait -PassThru
    if ($Test.ExitCode -ne 0) { throw 'Artwork or gaze validation failed' }
    $WindowsExe = (Resolve-Path (Join-Path $Dist 'windows-x64/Huhu.exe')).Path
    Write-Host "Packaging executable: $WindowsExe"
    Get-Item $WindowsExe | Select-Object FullName, Length
    $Nsis = if (Get-Command makensis.exe -ErrorAction SilentlyContinue) { 'makensis.exe' } else { "${env:ProgramFiles(x86)}/NSIS/makensis.exe" }
    & $Nsis /V3 "/DSOURCE_DIR=$Root" "/DDIST_DIR=$Dist" installer.nsi
    if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed' }
    Copy-Item "$Root/README.md", "$Root/THIRD_PARTY_NOTICES.md" "$Dist/windows-x64/"
    Copy-Item "$Root/licenses" "$Dist/windows-x64/" -Recurse -Force
    Compress-Archive -Path "$Dist/windows-x64/Huhu.exe", "$Dist/windows-x64/README.md", "$Dist/windows-x64/THIRD_PARTY_NOTICES.md", "$Dist/windows-x64/licenses" -DestinationPath "$Dist/Huhu-1.2.2-windows-x64-portable.zip" -Force
} finally { Pop-Location }
