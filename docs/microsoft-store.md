# Microsoft Store release

Calico Sleuth uses the same unsigned MSIX submission approach as 7TXT and Bediz. Microsoft signs the package after certification. The unsigned MSIX is for Partner Center upload, not a direct-download installer.

- Reserved name: Calico Sleuth
- Store ID: 9P6GJDKZ9FDM
- Identity: OrhanGkl.CalicoSleuth
- Publisher: CN=A9F0208B-CC43-472D-AE82-9FE4556DC935
- Publisher display name: Orhan Gökçöl
- Application version: 0.1.2
- Store package version: 1.0.2.0 (independent four-part version with nonzero major and zero revision)
- Target: Windows 11 x64, using its system Evergreen WebView2 runtime
- Capability: runFullTrust, required for the native desktop filesystem search and Windows Search integration
- Privacy URL: https://github.com/gokcol/MyFind/blob/main/PRIVACY.md
- Support URL: https://github.com/gokcol/MyFind/issues

The package uses standard MSIX virtualization. Store and direct-download installations may have separate local settings. No background task, startup registration, network service, or additional capability is requested.

## Listing copy

**Short description:** Find files by name, type, size, and date with flexible rules and local search.

**Description:**

Calico Sleuth helps you track down files with a curious calico cat at your side.

Choose folders, describe a common search in plain language, review the interpreted rules, and search. Filter by file name, path, extension, kind, size, and creation, modification, or access date. Combine rules with ALL or ANY and use wildcards or regular expressions.

On Windows, use Windows Search indexes for quick candidates or scan your selected folders directly. Hybrid mode combines both. Results appear as they are found. Inspect file metadata, reveal a match in File Explorer, save searches locally, and export results as CSV.

Common search phrases are supported in English, German, French, Spanish, and Turkish. Additional language packs can be imported. The interface is in English.

Your files and searches stay on your device. No account, advertising, analytics, or subscription is required.

Version 0.1.2 is an early release. "File & Content Search" is our product subtitle; searching inside documents is planned and is not available yet. Current searches use file names and metadata. Natural-language support covers common patterns, not arbitrary sentences. Results are capped at 50,000 and index-only coverage may be incomplete.

## Certification notes

The app is a full-trust Tauri desktop utility. It reads file-system metadata in user-selected locations and invokes the built-in PowerShell Windows Search provider in indexed modes. It does not elevate privileges or bypass Windows permissions. Use Thorough mode to test without relying on index coverage. No sign-in or test account is needed.

Search a folder containing sample files, enter a name fragment, and click Search. Use Rules to add extension, size, and date criteria. Select a result to view metadata; double-click to reveal it in File Explorer. Content search is not implemented and is not advertised as currently available.

## Packaging

The Windows CI job builds real-identity and disposable test-identity MSIX packages, validates the manifest and executable round trip, and tests the packaged app on the disposable runner. Only the real-identity unsigned package is suitable for submission. Check test reports and screenshots before submission.
