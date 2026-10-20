# Huhu 1.1.0

- Added **Run at startup** to Huhu’s right-click and menu-bar/tray menus on Mac and Windows.
- Startup is opt-in and off by default. Turn it on to open Huhu after signing in; turn it off to remove the registration.
- Mac uses native Login Items and guides you to System Settings when approval is needed. Install Huhu in Applications before enabling.
- Windows uses a per-user startup entry with a quoted executable path. Uninstall removes the entry for that installed copy.
- Added Windows startup enable/disable and uninstall-cleanup checks to CI.

The release includes a universal Mac DMG and ZIP, Windows x64 Setup EXE and portable ZIP, and SHA-256 checksums. GitHub's automatic source archives contain the complete project.

Validation includes native macOS and Windows builds, all 73 frames, sixteen gaze sectors, animation timing, and a Windows installation/startup/uninstallation smoke test. Mac desktop controls were checked on Apple Silicon. Full manual Windows interaction and multi-monitor testing remain pending.

**Signing:** These initial development packages are not signed for public distribution. The Mac app is ad-hoc signed and not notarized; the Windows files are not Authenticode-signed. Your operating system may show a warning when opening a downloaded package.
