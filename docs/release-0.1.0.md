# MyFind 0.1.0

First usable release of MyFind: a local desktop file finder with a clean Workspace interface.

## Included
- Search multiple folders by filename, extension, path, kind, size, and filesystem dates.
- ALL/ANY rule combinations, wildcards, regular expressions, and case-sensitive matching.
- Hybrid, indexed-only, and direct filesystem search modes.
- Spotlight on macOS and Windows Search integration on Windows.
- Streaming results, cancellation, sortable virtualized lists, and a metadata pane.
- Reveal in file manager, copy path, CSV export, and saved searches.
- Common search phrases in English, German, French, Spanish, and Turkish.
- Importable JSON language packs; an Italian example is included in the repository.
- Light and dark appearance follows the system.

## Downloads
- macOS: notarized Developer ID application for Apple Silicon (arm64), supplied as ZIP. Extract and move MyFind.app to Applications.
- Windows: x64 NSIS installer built by GitHub Actions. The installer is unsigned.
- Linux: x64 AppImage and Debian package built by GitHub Actions.

## Known limitations
This early release is not yet full Find Any File parity. Content search, document previews, nested Boolean groups, tags/comments, Windows hidden-attribute support, and advanced locale-specific case folding are planned. Natural-language parsing supports documented patterns; review the generated rules. Native indexes can be incomplete or outdated. Hybrid follows indexed results with a scan. Linux uses direct scanning. Creation/access timestamps depend on the filesystem. Search results are capped at 50,000; permission errors and limits are reported. Symlinks are not followed.

## Validation
Rust filesystem/filter/cancellation tests and multilingual parser tests run in CI. Windows and Linux packages are built on their respective GitHub runners. Mac signing and notarization are validated before publication.
