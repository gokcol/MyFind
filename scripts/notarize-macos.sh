#!/bin/bash
set -euo pipefail
# Uses credentials already stored in the local keychain. Never exports them.
identity=${MYFIND_SIGN_IDENTITY:?Set Developer ID identity}
profile=${MYFIND_NOTARY_PROFILE:?Set existing notarytool keychain profile}
app="src-tauri/target/release/bundle/macos/Tapp Find.app"
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist")
out="artifacts/macos-$version"
mkdir -p "$out"
codesign --force --deep --options runtime --timestamp --sign "$identity" "$app"
codesign --verify --deep --strict --verbose=2 "$app"
ditto -c -k --keepParent "$app" "$out/Tapp-Find-notary.zip"
xcrun notarytool submit "$out/Tapp-Find-notary.zip" --keychain-profile "$profile" --wait --output-format json > "$out/notary.json"
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(r); sys.exit(0 if r.get("status")=="Accepted" else 1)' "$out/notary.json"
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
ditto -c -k --keepParent "$app" "$out/Tapp-Find-$version-macos-arm64.zip"
