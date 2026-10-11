#!/bin/zsh
# Crea (una volta) un'identità di firma autofirmata per Nod, in un portachiavi suo: ~/.nod-signing/.
#
# Perché: con la firma ad hoc ogni build ha un'identità diversa, quindi a ogni aggiornamento macOS dimentica i permessi dati
# (Movimento e fitness, Bluetooth…). Firmate con questa identità, tutte le build hanno lo stesso requisito
# ("identifier local.nod.companion e questo certificato") e macOS conserva i permessi. Stesso approccio di Cocaine
# (make-signing-identity.sh, licenza MIT). Non è riconosciuta da Gatekeeper: per quello serve un Developer ID.
# La chiave resta su questo Mac. La password del portachiavi non è un segreto: protegge solo questa identità di build.
# Tienila: un'identità nuova (altro Mac, cartella cancellata) per macOS è un'altra app.
set -euo pipefail
DIR="$HOME/.nod-signing"
KC="$DIR/nod-signing.keychain"
NAME="Nod Local Signing"
PASS="nod"

if [ -f "$KC" ] && security find-certificate -c "$NAME" "$KC" >/dev/null 2>&1; then
  echo "Identità già presente: $KC"
  exit 0
fi
mkdir -p "$DIR"; chmod 700 "$DIR"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/cert.cnf" <<'CNF'
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = Nod Local Signing
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -days 7300 \
  -config "$WORK/cert.cnf" >/dev/null 2>&1
/usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -out "$WORK/id.p12" -passout "pass:$PASS" \
  -name "$NAME" >/dev/null 2>&1
rm -f "$KC"
security create-keychain -p "$PASS" "$KC"
security set-keychain-settings "$KC"
security unlock-keychain -p "$PASS" "$KC"
security import "$WORK/id.p12" -k "$KC" -P "$PASS" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k "$PASS" "$KC" >/dev/null 2>&1 || true
echo "Creata: $KC"
