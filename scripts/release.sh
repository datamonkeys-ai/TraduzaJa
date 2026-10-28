#!/bin/bash
# Gera release assinada (Developer ID) e notarizada do TraduzaJa.
# Uso: scripts/release.sh            -> dist/TraduzaJa-<versão>-mac.zip
# Requer: identidade "Developer ID Application" no keychain e a chave
# do App Store Connect em ~/.appstoreconnect/private_keys/AuthKey_$NOTARY_KEY_ID.p8
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${IDENTITY:-Developer ID Application: Louis Perner (886XWSBVN5)}"
NOTARY_KEY_ID="${NOTARY_KEY_ID:-L7K48VFTP3}"
NOTARY_ISSUER="${NOTARY_ISSUER:-62a26273-ac6d-487f-9332-5cff392e5d5b}"
NOTARY_KEY="$HOME/.appstoreconnect/private_keys/AuthKey_$NOTARY_KEY_ID.p8"

VERSION=$(sed -n 's/.*MARKETING_VERSION: "\(.*\)".*/\1/p' project.yml)
BUILD=$(sed -n 's/.*CURRENT_PROJECT_VERSION: "\(.*\)".*/\1/p' project.yml)
ARCHIVE=build/TraduzaJa.xcarchive
APP="$ARCHIVE/Products/Applications/TraduzaJa.app"
DIST=dist
ZIP="$DIST/TraduzaJa-$VERSION-mac.zip"

echo "== archive $VERSION ($BUILD)"
xcodegen generate >/dev/null
rm -rf "$ARCHIVE"
xcodebuild archive -scheme TraduzaJa -configuration Release \
  -archivePath "$ARCHIVE" -derivedDataPath build \
  -allowProvisioningUpdates -quiet

echo "== codesign (Developer ID, hardened runtime, timestamp)"
cat > build/release.entitlements <<'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict/></plist>
ENT
codesign --force --deep --options runtime --timestamp \
  --entitlements build/release.entitlements \
  --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "== zip + notarize"
mkdir -p "$DIST"; rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" \
  --issuer "$NOTARY_ISSUER" --wait

echo "== staple + re-zip"
xcrun stapler staple "$APP"
rm -f "$ZIP"; ditto -c -k --keepParent "$APP" "$ZIP"
spctl --assess --type execute --verbose=2 "$APP"
shasum -a 256 "$ZIP" | tee "$ZIP.sha256"
echo "OK: $ZIP"
