# Tapp Find 0.1.3

**File & Content Search**

Calico Sleuth is now **Tapp Find**. This release updates the app window, sidebar, installers, export filename, and current documentation. The searching calico cat icon and subtitle are unchanged.

The app identifiers and saved-search/language-pack storage remain stable. Search behavior is unchanged: find files by name, path, extension, kind, size, and dates; combine rules; use native indexes or direct scans; interpret common phrases in English, German, French, Spanish, and Turkish; save searches and export CSV.

**Content search is planned and is not included in this version.** Current searches use filenames and metadata.

## Downloads

- macOS Apple Silicon: Developer ID signed, notarized, and stapled application ZIP. Quit the old app, extract Tapp Find.app, and move it to Applications.
- Windows x64: unsigned NSIS installer built and tested by GitHub Actions.
- Linux x64: AppImage and Debian package built by GitHub Actions.
- SHA256SUMS.txt contains checksums for all four packages.

Repository: [gokcol/Tapp](https://github.com/gokcol/Tapp).

## Microsoft Store

Tapp Find is reserved for the existing Microsoft Store product. The updated MSIX package is version 1.0.3.0. Store publication is subject to Microsoft's certification; GitHub downloads are available independently.

## Known limitations

This is an early release, not full Find Any File parity. Content search, previews, nested Boolean groups, Finder tags, and Windows hidden/system attribute filters are not implemented. Searches respect OS permissions; index-only coverage may be incomplete. Results are capped at 50,000. Natural-language parsing supports common patterns rather than arbitrary sentences.
