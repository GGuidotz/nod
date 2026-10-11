#!/bin/zsh
# Pubblica una versione di Nod, come fa Cocaine col suo tap:
#   1. ./build.sh --dmg (firma con l'identità locale)
#   2. release GitHub v<versione> nel repo dell'app, con il DMG e le note prese da CHANGELOG.md (serve `gh auth login`)
#   3. aggiorna version e sha256 del cask, qui e nel clone del tap, e lo pubblica
# Prima: aumenta VERSION e aggiungi in cima a CHANGELOG.md la sezione "## <versione> · <data>".
# Repo (cambiabili): NOD_APP_REPO=GGuidotz/nod  NOD_TAP_DIR=~/Developer/homebrew-tap (clone di GGuidotz/homebrew-tap)
set -euo pipefail
cd "${0:A:h}"
die() { echo "$*" >&2; exit 1; }

APP_REPO=${NOD_APP_REPO:-GGuidotz/nod}
TAP_DIR=${NOD_TAP_DIR:-$HOME/Developer/homebrew-tap}
VERSION=$(tr -d '[:space:]' < VERSION)
CASK=packaging/homebrew/Casks/nod.rb

command -v gh >/dev/null || die "Serve GitHub CLI: brew install gh && gh auth login"
[ -z "$(git status --porcelain -- .)" ] || die "Ci sono modifiche non salvate in git: fai prima il commit."
gh release view "v$VERSION" --repo "$APP_REPO" >/dev/null 2>&1 && die "La release v$VERSION esiste già: aumenta VERSION."

./build.sh --dmg
DMG="dist/Nod-$VERSION.dmg"
SHA=$(shasum -a 256 "$DMG" | cut -d' ' -f1)
NOTES=$(awk -v v="$VERSION" '$0 ~ "^## "v" " {f=1; next} /^## / {f=0} f' CHANGELOG.md)

gh release create "v$VERSION" "$DMG" --repo "$APP_REPO" --title "Nod $VERSION" --notes "$NOTES"

sed -i '' -e "s/^  version \".*\"/  version \"$VERSION\"/" -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK"
git add "$CASK" && git commit -m "Cask nod $VERSION" -- "$CASK" >/dev/null || true

if [ -d "$TAP_DIR/.git" ]; then
  mkdir -p "$TAP_DIR/Casks"
  cp "$CASK" "$TAP_DIR/Casks/nod.rb"
  git -C "$TAP_DIR" add Casks/nod.rb
  git -C "$TAP_DIR" commit -m "nod $VERSION" >/dev/null
  git -C "$TAP_DIR" push
  echo "Tap aggiornato."
else
  echo "Tap non trovato in $TAP_DIR: copia a mano $CASK in Casks/ del repo homebrew-tap."
fi
echo "Pubblicato Nod $VERSION. Chi lo usa: brew update && brew upgrade --cask nod"
