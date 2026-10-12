#!/bin/zsh
# Compila Nod.app (universale arm64 + x86_64, macOS 14+) con gli strumenti a riga di comando: niente progetto Xcode.
#   ./build.sh              build/Nod.app
#   ./build.sh --install    e la copia in /Applications (chiude la copia aperta)
#   ./build.sh --dmg        e crea dist/Nod-<versione>.dmg (rifiuta la firma ad hoc: i permessi andrebbero persi)
#   NOD_ICON=classic ./build.sh …   usa l'icona classica anche se c'è Xcode
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
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
BUILD=build
APP="$BUILD/Nod.app"
PLIST="$APP/Contents/Info.plist"
KC="$HOME/.nod-signing/nod-signing.keychain"
IDENTITY="Nod Local Signing"
plist_set() { /usr/bin/plutil -insert "$1" -string "$2" "$PLIST"; }   # chiave, valore (spazi ammessi)

grep -q "^## $VERSION " CHANGELOG.md || { echo "Manca la sezione '## $VERSION · <data>' in CHANGELOG.md" >&2; exit 1; }

# Traduzioni: ogni L("…") deve avere la sua voce in en/fr/es (avviso, non blocca).
if command -v python3 >/dev/null; then
  python3 -I tools/check-strings.py >/dev/null || echo "Attenzione: traduzioni incomplete (python3 tools/check-strings.py)."
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" Resources/Info.plist > "$PLIST"
cp CHANGELOG.md "$APP/Contents/Resources/CHANGELOG.md"
cp -R Localization/*.lproj "$APP/Contents/Resources/"

for arch in arm64 x86_64; do
  mkdir -p "$BUILD/$arch"
  swiftc -O -swift-version 5 -parse-as-library -target "$arch-apple-macos14.0" Sources/*.swift -o "$BUILD/$arch/Nod"
done
lipo -create "$BUILD/arm64/Nod" "$BUILD/x86_64/Nod" -output "$APP/Contents/MacOS/Nod"

# Icona classica (.icns), sempre: macOS precedenti e ripiego.
ICONSET="$BUILD/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/Icon/AppIcon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) Resources/Icon/AppIcon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Icona Liquid Glass (Resources/Icon/Nod.icon, formato Icon Composer): serve actool di Xcode. Accettata solo se il catalogo
# compilato contiene davvero l'icona "Nod"; altrimenti si resta sulla classica (un catalogo vuoto lascia il Dock vuoto).
ICON_TIER=classic
if [ "${NOD_ICON:-}" != classic ]; then
  if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer   # Xcode anche se è selezionato solo CLT
  fi
  ACTOOL=$(xcrun --find actool 2>/dev/null || true)
  ASSETUTIL=$(xcrun --find assetutil 2>/dev/null || command -v assetutil || true)
  if [ -n "$ACTOOL" ]; then
    rm -rf "$BUILD/icon-out"; mkdir -p "$BUILD/icon-out"
    if "$ACTOOL" Resources/Icon/Nod.icon --compile "$BUILD/icon-out" --platform macosx --target-device mac \
         --minimum-deployment-target 14.0 --app-icon Nod --output-partial-info-plist "$BUILD/icon-partial.plist" \
         >"$BUILD/actool.log" 2>&1 && [ -f "$BUILD/icon-out/Assets.car" ] \
       && { [ -z "$ASSETUTIL" ] || grep -Eq '"Name" *: *"Nod"' <<< "$("$ASSETUTIL" --info "$BUILD/icon-out/Assets.car" 2>/dev/null)"; }; then
      cp "$BUILD/icon-out/Assets.car" "$APP/Contents/Resources/"
      plist_set CFBundleIconName Nod
      ICON_TIER="liquid-glass"
    else
      echo "Icona Liquid Glass non valida (dettagli in $BUILD/actool.log): uso l'icona classica."
    fi
  else
    echo "actool non trovato (serve Xcode): icona classica."
  fi
fi

# Firma: decisa prima, perché l'Info.plist va completato prima di firmare.
if [ -f "$KC" ]; then
  TIER=local
else
  [ "$MODE" = dmg ] && { echo "Per un DMG serve l'identità: ./make-signing-identity.sh" >&2; exit 1; }
  TIER=adhoc
fi

# Dati per la diagnostica e per gli aggiornamenti (Sources/Diagnostics.swift, Sources/Updater.swift).
plist_set NodGitCommit "$COMMIT"
plist_set NodIconTier "$ICON_TIER"
plist_set NodSigningTier "$TIER"
[ "$MODE" = dmg ] || plist_set NodSourcePath "$PWD"
plutil -lint "$PLIST" >/dev/null

if [ "$TIER" = local ]; then
  security unlock-keychain -p nod "$KC"
  codesign --force --keychain "$KC" --sign "$IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
  echo "Attenzione: firma ad hoc. macOS chiederà di nuovo i permessi a ogni build. ./make-signing-identity.sh lo evita."
fi
codesign --verify --strict "$APP"
echo "Pronto: $APP ($VERSION, build $BUILD_NUMBER, commit $COMMIT, firma $TIER, icona $ICON_TIER)"

case "$MODE" in
  install)
    /usr/bin/pkill -x Nod 2>/dev/null || true
    rm -rf /Applications/Nod.app
    cp -R "$APP" /Applications/Nod.app
    # Il Dock e il Finder tengono in cache l'icona vecchia: registra di nuovo l'app.
    touch /Applications/Nod.app
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Nod.app \
      2>/dev/null || true
    open /Applications/Nod.app
    echo "Installato in /Applications. Se il Dock mostra ancora l'icona vecchia: killall Dock" ;;
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
