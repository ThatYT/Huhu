# Huhu 1.0.0

- Standalone plush tiger desktop companion for macOS and Windows.
- Nine animations and sixteen pointer-following gaze directions.
- Drag to move, click to wave, double-click to jump.
- Menu bar/tray controls for size, pause, hide/show, and quit.
- Universal macOS app (Apple Silicon + Intel), DMG and ZIP.
- Windows x64 per-user installer with Start Menu and uninstall support, plus portable ZIP.
- Runs locally without an account, AI service, or extra runtime.

The release includes a universal Mac DMG and ZIP, Windows x64 Setup EXE and portable ZIP, and SHA-256 checksums. GitHub's automatic source archives contain the complete project.

Validation includes native macOS and Windows builds, all 73 frames, sixteen gaze sectors, animation timing, and a Windows installation/startup/uninstallation smoke test. Mac desktop controls were checked on Apple Silicon. Full manual Windows interaction and multi-monitor testing remain pending.

**Signing:** These initial development packages are not signed for public distribution. The Mac app is ad-hoc signed and not notarized; the Windows files are not Authenticode-signed. Your operating system may show a warning when opening a downloaded package.
