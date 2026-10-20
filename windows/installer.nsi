Unicode true
!include "MUI2.nsh"
!include "x64.nsh"
!include "WinVer.nsh"
!ifndef SOURCE_DIR
  !define SOURCE_DIR ".."
!endif
!ifndef DIST_DIR
  !define DIST_DIR "..\dist"
!endif
Name "Huhu"
OutFile "${DIST_DIR}\Huhu-1.0.0-windows-x64-setup.exe"
InstallDir "$LOCALAPPDATA\Programs\Huhu"
InstallDirRegKey HKCU "Software\Huhu" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
Icon "${SOURCE_DIR}\assets\Huhu.ico"
UninstallIcon "${SOURCE_DIR}\assets\Huhu.ico"
VIProductVersion "1.0.0.0"
VIAddVersionKey /LANG=1033 "ProductName" "Huhu"
VIAddVersionKey /LANG=1033 "FileDescription" "Huhu Setup"
VIAddVersionKey /LANG=1033 "FileVersion" "1.0.0"
VIAddVersionKey /LANG=1033 "LegalCopyright" "Huhu desktop companion"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\Huhu.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch Huhu"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "Huhu requires 64-bit Windows 10 or later."
    Abort
  ${EndIf}
  ${IfNot} ${AtLeastWin10}
    MessageBox MB_ICONSTOP "Huhu requires Windows 10 or later."
    Abort
  ${EndIf}
  SetRegView 64
FunctionEnd

Section "Huhu"
  FindWindow $0 "HuhuDesktopCompanion"
  ${If} $0 != 0
    SendMessage $0 ${WM_CLOSE} 0 0 /TIMEOUT=3000
    Sleep 400
  ${EndIf}
  SetOutPath "$INSTDIR"
  File "${DIST_DIR}\windows-x64\Huhu.exe"
  File "${SOURCE_DIR}\README.md"
  File "${SOURCE_DIR}\THIRD_PARTY_NOTICES.md"
  SetOutPath "$INSTDIR\licenses"
  File "${SOURCE_DIR}\licenses\*"
  SetOutPath "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\Huhu"
  CreateShortcut "$SMPROGRAMS\Huhu\Huhu.lnk" "$INSTDIR\Huhu.exe"
  CreateShortcut "$SMPROGRAMS\Huhu\Uninstall Huhu.lnk" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Huhu" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Huhu" "DisplayName" "Huhu"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Huhu" "DisplayVersion" "1.0.0"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Huhu" "DisplayIcon" "$INSTDIR\Huhu.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Huhu" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Huhu" "QuietUninstallString" '$\"$INSTDIR\Uninstall.exe$\" /S'
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Huhu" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Huhu" "NoRepair" 1
SectionEnd

Section "Uninstall"
  SetRegView 64
  FindWindow $0 "HuhuDesktopCompanion"
  ${If} $0 != 0
    SendMessage $0 ${WM_CLOSE} 0 0 /TIMEOUT=3000
    Sleep 400
  ${EndIf}
  Delete "$INSTDIR\Huhu.exe"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\THIRD_PARTY_NOTICES.md"
  Delete "$INSTDIR\licenses\mingw-w64.txt"
  Delete "$INSTDIR\licenses\NSIS.txt"
  Delete "$INSTDIR\licenses\GPL-3.0.txt"
  Delete "$INSTDIR\licenses\GCC-RUNTIME-EXCEPTION.txt"
  RMDir "$INSTDIR\licenses"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\Huhu\Huhu.lnk"
  Delete "$SMPROGRAMS\Huhu\Uninstall Huhu.lnk"
  RMDir "$SMPROGRAMS\Huhu"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Huhu"
  DeleteRegKey HKCU "Software\Huhu"
SectionEnd
