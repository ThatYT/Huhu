# Build and release

Version: 1.2.2.

## Repository and workflow

Repository: https://github.com/ThatYT/Huhu (public). This folder is the repository root. Keep the original pet workflow/reference-photo folders out of the repository.

The workflow builds on pull requests, pushes to main, and manual runs. It builds Windows natively on a Windows runner (including artwork/gaze and startup-registration validation) and macOS universally on a Mac runner. Artifacts are retained for review. A `v1.2.2` tag or a manual run with **Publish the 1.2.2 release** selected publishes a GitHub Release after both platform builds pass. Manual runs without that option only build artifacts.

CI checks Windows installation, installed-app startup, artwork/gaze data, Start Menu registration, uninstall registration, and removal. Full manual Windows desktop interaction still needs checks for dragging, gaze, menus, scaling across monitors, and upgrades on supported Windows versions.

## Release checklist

1. Update version strings and filenames in Info.plist, Windows resources/manifest/installer, build scripts, release workflow, and release notes together.
2. Run the animation tests and both platform builds.
3. Perform the Windows install/UI/uninstall smoke test; inspect the Mac DMG and test the universal app on the target architectures.
4. For public distribution, add Developer ID signing and Apple notarization for macOS and Authenticode signing for Windows. These require the owner's certificates/accounts and are not present in this package.
5. Create the version tag or run the workflow with its release option after source review. Verify the published release assets and checksums.

The supplied unsigned-development workflow can be run without signing secrets. Tagged release builds publish only after both platform jobs pass. Source and artwork licensing should be chosen by the owner before distributing an open-source release.
