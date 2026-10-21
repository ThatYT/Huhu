# Huhu 1.2.0

- Hover over Huhu’s body for a randomly chosen wave or jump. Move away and return for another greeting, with an eight-second cooldown.
- Huhu occasionally plays **Think** after 20–45 seconds of idle time. Interacting resets the idle interval.
- Automatic animations respect pause, hide, open menus, and system reduced-motion settings. They do not interrupt dragging or another animation.
- Added matching Mac and Windows behavior tests for hover entries, cooldowns, idle timing, and suppression.

The release includes a universal Mac DMG and ZIP, Windows x64 Setup EXE and portable ZIP, and SHA-256 checksums. GitHub's automatic source archives contain the complete project.

Validation includes native macOS and Windows builds, all 73 frames, sixteen gaze sectors, animation timing, and a Windows installation/startup/uninstallation smoke test. Mac desktop controls were checked on Apple Silicon. Full manual Windows interaction and multi-monitor testing remain pending.

**Signing:** These initial development packages are not signed for public distribution. The Mac app is ad-hoc signed and not notarized; the Windows files are not Authenticode-signed. Your operating system may show a warning when opening a downloaded package.
