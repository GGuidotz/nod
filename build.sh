#!/bin/zsh
# Compila Nod.app (universale arm64 + x86_64, macOS 14+) con gli strumenti a riga di comando: niente progetto Xcode.
#   ./build.sh              build/Nod.app
#   ./build.sh --install    e la copia in /Applications (chiude la copia aperta)
#   ./build.sh --dmg        e crea dist/Nod-<versione>.dmg (rifiuta la firma ad hoc: i permessi andrebbero persi)
# Firma con l'identità di ./make-signing-identity.sh se c'è, altrimenti ad hoc (solo per prove).
set -euo pipefail
cd "${0:A:h}"

MODE=build
case "${1:-}" in
  --install) MODE=install ;;
  --dmg) MODE=dmg ;;
  "") ;;
  *) echo "uso: ./build.sh [--install|--dmg]" >&2; exit 64 ;;
esac

VERSION=$(tr -d '[:space:]' < VERSION)
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo 1)
BUILD=build
APP="$BUILD/Nod.app"
KC="$HOME/.nod-signing/nod-signing.keychain"
IDENTITY="Nod Local Signing"

grep -q "^## $VERSION " CHANGELOG.md || { echo "Manca la sezione '## $VERSION · <data>' in CHANGELOG.md" >&2; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" Resources/Info.plist > "$APP/Contents/Info.plist"
cp CHANGELOG.md "$APP/Contents/Resources/CHANGELOG.md"

for arch in arm64 x86_64; do
  mkdir -p "$BUILD/$arch"
  swiftc -O -swift-version 5 -parse-as-library -target "$arch-apple-macos14.0" Sources/*.swift -o "$BUILD/$arch/Nod"
done
lipo -create "$BUILD/arm64/Nod" "$BUILD/x86_64/Nod" -output "$APP/Contents/MacOS/Nod"

if [ -f "$KC" ]; then
  security unlock-keychain -p nod "$KC"
  codesign --force --keychain "$KC" --sign "$IDENTITY" "$APP"
  TIER=local
else
  [ "$MODE" = dmg ] && { echo "Per un DMG serve l'identità: ./make-signing-identity.sh" >&2; exit 1; }
  codesign --force --sign - "$APP"
  TIER=adhoc
  echo "Attenzione: firma ad hoc. macOS chiederà di nuovo i permessi a ogni build. ./make-signing-identity.sh lo evita."
fi
codesign --verify --strict "$APP"
echo "Pronto: $APP ($VERSION, build $BUILD_NUMBER, firma $TIER)"

case "$MODE" in
  install)
    /usr/bin/pkill -x Nod 2>/dev/null || true
    rm -rf /Applications/Nod.app
    cp -R "$APP" /Applications/Nod.app
    open /Applications/Nod.app
    echo "Installato in /Applications" ;;
  dmg)
    mkdir -p dist
    STAGE=$(mktemp -d)
    cp -R "$APP" "$STAGE/Nod.app"
    ln -s /Applications "$STAGE/Applications"
    DMG="dist/Nod-$VERSION.dmg"
    rm -f "$DMG"
    hdiutil create -quiet -volname "Nod $VERSION" -srcfolder "$STAGE" -format UDZO "$DMG"
    rm -rf "$STAGE"
    shasum -a 256 "$DMG"
    echo "DMG: $DMG" ;;
esac
