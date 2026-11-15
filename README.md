# MyFind 0.1.1

A local desktop file finder for macOS, Windows, and Linux. Built with Rust, Tauri 2, React, and TypeScript.

## Search

Choose one or more folders, enter a filename or a supported natural-language request, click **Interpret**, review the rules, then **Search**. Rules support names, paths, extensions, file/folder/symlink kind, size in bytes, and created/modified/accessed dates. String operators include contains, excludes, exact, prefix, suffix, wildcards, and regular expressions. Rules combine with ALL or ANY.

- **Hybrid**: native index candidates first, followed by a filesystem scan of selected locations.
- **Fast**: native index only; results are not exhaustive.
- **Thorough**: filesystem scan, available on all platforms.

macOS queries Spotlight using `mdfind`; Windows queries Windows Search through the built-in PowerShell/OLE DB provider. Index queries have a 30-second timeout. Linux currently supports the scanner; Hybrid falls back with an explanatory message. Symlinks are returned but never followed. Searches respect OS access permissions. Enable Full Disk Access yourself in macOS settings if you want protected locations to be searchable.

Results stream into a virtualized list. Select a file for metadata, reveal it in your file manager, copy its path, or export results as CSV. Double-click reveals a file. Save reusable searches locally. No accounts, telemetry, or cloud service.

## Natural language

English, German, French, Spanish, and Turkish support common PDF/image, size, last-month/last-seven-days, and created/modified phrases. For example: `PDF files modified last month` or `Geçen ay değiştirilen PDF dosyaları`. Quote a filename fragment to combine it with filters. The initial parser is intentionally limited: it shows interpreted rules for review and does not promise arbitrary sentence understanding. Unrecognized standalone text is matched literally against filenames. Size phrases use a greater-than comparison; edit the rule for smaller-than searches.

Import additional JSON language packs through **+ Language**. See `languages/it.json`. Packs are local data, not downloaded code. Interface labels are English in this release.

## Build

Install Node.js 22+, Rust stable, and the [Tauri prerequisites](https://v2.tauri.app/start/prerequisites/) for your OS.

```sh
npm ci
npm run tauri dev
npm test
cargo test --manifest-path src-tauri/Cargo.toml
npm run tauri build
```

GitHub Actions builds Windows NSIS installers and Linux AppImages/deb packages. Mac release builds are Developer ID signed and notarized locally without exporting signing credentials.

## 0.1 boundaries

This is a first usable release, not full Find Any File feature parity. It does not yet support content search, nested Boolean groups, Finder tags/comments, Windows ACL/attribute filters, previews, native drag-out, or a persistent MyFind index. Hidden exclusion covers dot-prefixed paths; Windows hidden/system flags are not yet handled. Case-insensitive matching uses Unicode lowercase, not locale-specific Turkish casing. Creation/access times may be unavailable or filesystem-dependent. Directory size is its own metadata size, not recursive contents. Results are capped at 50,000 and the status reports the cap. Windows binaries are unsigned; Linux packages are built in CI. Saved searches retain locations and rules; search options are session settings.

## Contributing

Report reproducible bugs with OS, search rules, and a synthetic sample directory. Do not upload personal filenames or documents. Run the Rust and parser tests before submitting changes. New language packs should include equivalent examples and expected rules.

## License

MIT. See LICENSE.
