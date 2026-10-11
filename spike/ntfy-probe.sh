#!/bin/zsh
# Prova: notifica ntfy con pulsanti sull'iPhone, rispecchiata sul Watch; il doppio tap esegue il primo pulsante?
#   ./ntfy-probe.sh [server]     (default https://ntfy.sh)
# Crea due topic casuali (il nome fa da segreto), manda una notifica con Approva / Nega e aspetta la risposta.
SERVER=${1:-https://ntfy.sh}
TOPIC="cocaine-probe-$(/usr/bin/openssl rand -hex 12)"
REPLY="$TOPIC-r"

print "1. Nell'app ntfy dell'iPhone iscriviti a questo topic (server: $SERVER):"
print "   $TOPIC"
print "2. Sul Watch: Impostazioni > Gesti > Doppio tap attivo."
read "?Premi Invio quando sei iscritto... "

/usr/bin/curl -s -o /dev/null \
  -H "Title: Claude: permesso" \
  -H "Priority: high" \
  -H "Actions: http, Approva, $SERVER/$REPLY, method=POST, body=allow, clear=true; http, Nega, $SERVER/$REPLY, method=POST, body=deny, clear=true" \
  -d "progetto-x: npm test. Doppio tap = primo pulsante." \
  "$SERVER/$TOPIC"
START=$(date +%s)
print "Notifica inviata. Sul Watch prova il doppio tap (poi rilancia la prova e prova il tocco sul pulsante). Ctrl-C per uscire."

/usr/bin/curl -sN "$SERVER/$REPLY/json?since=$START" | while IFS= read -r line; do
  [[ $line == *'"event":"message"'* ]] || continue
  msg=${${line##*\"message\":\"}%%\"*}
  print "$(date +%T) risposta: $msg dopo $(( $(date +%s) - START )) s"
done
