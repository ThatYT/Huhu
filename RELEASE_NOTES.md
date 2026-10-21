# Huhu 1.2.1

- Fixed Windows run direction when reversing a drag: Huhu now follows the latest horizontal movement, including slow one-pixel changes, without needing to cross the drag’s starting point. Vertical movement keeps the last direction.
- Hover over Huhu for a random two or three complete jumps, followed by Think. The sequence plays once per hover, with an eight-second cooldown before another entry can trigger it.
- Leaving Huhu, dragging, choosing another animation, pausing, hiding, or opening a menu cancels queued hover moves. Reduced motion suppresses automatic animations.
- Retained occasional idle thinking after 20–45 seconds, and added regression checks for drag reversals and hover sequences.

The release includes a universal Mac DMG and ZIP, Windows x64 Setup EXE and portable ZIP, and SHA-256 checksums. GitHub's automatic source archives contain the complete project.

Validation includes native macOS and Windows builds, all 73 frames, sixteen gaze sectors, animation timing, and a Windows installation/startup/uninstallation smoke test. Mac desktop controls were checked on Apple Silicon. Full manual Windows interaction and multi-monitor testing remain pending.

**Signing:** These initial development packages are not signed for public distribution. The Mac app is ad-hoc signed and not notarized; the Windows files are not Authenticode-signed. Your operating system may show a warning when opening a downloaded package.
