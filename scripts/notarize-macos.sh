#!/bin/bash
set -euo pipefail
# Uses credentials already stored in the local keychain. Never exports them.
identity=${MYFIND_SIGN_IDENTITY:?Set Developer ID identity}
profile=${MYFIND_NOTARY_PROFILE:?Set existing notarytool keychain profile}
app=src-tauri/target/release/bundle/macos/MyFind.app
out=artifacts/macos
mkdir -p "$out"
codesign --force --deep --options runtime --timestamp --sign "$identity" "$app"
codesign --verify --deep --strict --verbose=2 "$app"
ditto -c -k --keepParent "$app" "$out/MyFind-notary.zip"
xcrun notarytool submit "$out/MyFind-notary.zip" --keychain-profile "$profile" --wait --output-format json > "$out/notary.json"
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(r); sys.exit(0 if r.get("status")=="Accepted" else 1)' "$out/notary.json"
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
ditto -c -k --keepParent "$app" "$out/MyFind-0.1.0-macos-arm64.zip"
