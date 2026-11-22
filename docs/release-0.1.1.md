# MyFind 0.1.1

MyFind now has its own searching calico cat mascot: a curious orange, white, and charcoal cat peering through a magnifying glass.

- Replaced the placeholder application icon across macOS, Windows, and Linux.
- Added the mascot to the application's sidebar and browser favicon.
- Included the master artwork and reproducible icon-generation instructions.
- Updated macOS notarization packaging to derive the version from the built app.

## Downloads
- macOS Apple Silicon: Developer ID signed, notarized, and stapled application ZIP. Extract and move MyFind.app to Applications.
- Windows x64: NSIS installer built by GitHub Actions; unsigned.
- Linux x64: AppImage and Debian package built by GitHub Actions.

Search functionality and known limitations are as documented in the [0.1.0 release](https://github.com/gokcol/Tapp/releases/tag/v0.1.0). All 12 automated tests pass locally. The native icon was inspected at small sizes; target-platform packages are built and tested in CI.
