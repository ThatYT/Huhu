# Huhu 1.2.2

- Stabilized Windows run direction during dragging: Huhu keeps facing the same way through small pointer wobbles, and switches after eight logical pixels of reverse movement.
- The direction buffer follows the furthest point of the drag. Slow reversals work without crossing the original starting point, and the buffer scales with display DPI.
- Added regression checks for repeated jitter, gradual reversals in both directions, vertical motion, new drags, and high-DPI scaling.
- Hover still plays two or three jumps followed by Think; occasional idle thinking is unchanged.

The release includes a universal Mac DMG and ZIP, Windows x64 Setup EXE and portable ZIP, and SHA-256 checksums. GitHub's automatic source archives contain the complete project.

Validation includes native macOS and Windows builds, all 73 frames, sixteen gaze sectors, animation timing, and a Windows installation/startup/uninstallation smoke test. Mac desktop controls were checked on Apple Silicon. Full manual Windows interaction and multi-monitor testing remain pending.

**Signing:** These initial development packages are not signed for public distribution. The Mac app is ad-hoc signed and not notarized; the Windows files are not Authenticode-signed. Your operating system may show a warning when opening a downloaded package.
