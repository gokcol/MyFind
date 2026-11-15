# Architecture

The React interface sends typed query objects through Tauri IPC. A Rust worker manages each search, with cancellation flags and bounded batches emitted to the window. A job identifier prevents old searches from overwriting new results. A 50,000-result cap bounds retained hits. The UI virtualizes rows.

Native providers enumerate indexed candidates through Spotlight's `mdfind` on Mac and Windows Search OLE DB through PowerShell on Windows. The Windows adapter explicitly emits UTF-8. Index workers are cancelled or killed after 30 seconds; Hybrid then scans the chosen scope. All candidates pass the same filesystem metadata matcher. The scanner does not follow symlinks and supports search depth and dot-file/package exclusions.

Natural-language packs map a small documented vocabulary to the same query rules. No model or cloud inference is included. Future work: compile query patterns once, parallel directory walking, native metadata adapters, native index predicate pushdown, persistent SQLite stores, nested query trees, and isolated content extractors.

## Release

Build and test on the target OS. GitHub Actions uploads Windows and Linux packages as run artifacts. For macOS, build with `npm run tauri build -- --bundles app`, then run `scripts/notarize-macos.sh` with `MYFIND_SIGN_IDENTITY` and `MYFIND_NOTARY_PROFILE`. The script checks Apple acceptance, staples the app, assesses Gatekeeper, and creates the distributable ZIP. Publish only after the same source revision passes all jobs. Keep signing keys and notarization credentials out of the repository and CI artifacts.
