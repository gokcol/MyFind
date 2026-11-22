# Calico Sleuth 0.1.2

**File & Content Search**

MyFind is now Calico Sleuth, with the same searching calico cat mascot. This release introduces the new name across the application window, sidebar, installers, and CSV export filename.

## Available now

- Search file names, paths, extensions, types, sizes, and creation/modification/access dates.
- Combine rules with ALL or ANY; use regular expressions and wildcards.
- Use Spotlight on macOS or Windows Search on Windows, with a filesystem scan option on every platform.
- Interpret common search phrases in English, German, French, Spanish, and Turkish; import additional language packs.
- Save searches locally, inspect metadata, reveal matches, and export results as CSV.

**Content search is planned and is not included in version 0.1.2.** The subtitle describes the product direction. Current searches use file names and metadata.

## Downloads

- macOS Apple Silicon: Developer ID signed, notarized, and stapled application ZIP. Extract Calico Sleuth.app and move it to Applications. Quit MyFind before replacing your previous installation; remove the old app copy after confirming the new app works.
- Windows x64: unsigned NSIS installer built by GitHub Actions.
- Linux x64: AppImage and Debian package built by GitHub Actions.
- SHA256SUMS.txt contains checksums for all four packages.

The bundle identifier and saved-search/language-pack storage keys are unchanged. The repository is now [gokcol/Tapp](https://github.com/gokcol/Tapp).

## Limitations

This is an early release, not full Find Any File parity. Content search, previews, nested Boolean groups, Finder tags, and Windows hidden/system attribute filters are not implemented. Searches respect OS permissions; index-only results may be incomplete. Results are capped at 50,000. The natural-language parser supports common patterns rather than arbitrary sentences.

Microsoft Store submission was completed on 22 November 2026 and is awaiting certification. It is configured to publish automatically after approval. The [Store listing](https://apps.microsoft.com/detail/9P6GJDKZ9FDM) may not be available until publishing finishes. GitHub downloads are available now.
