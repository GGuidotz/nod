#!/bin/zsh
# Avvia SensorProbe come app (così macOS chiede i permessi a lei, non al Terminale) e ne mostra l'output qui.
#   ./run.sh head | watch [motivo] | stem [mic] [audio]
cd "${0:A:h}"
[[ -d build/SensorProbe.app ]] || ./build.sh
trap '/usr/bin/pkill -x SensorProbe; exit 0' INT TERM
TTY=$(tty)
/usr/bin/open -n -W --stdout "$TTY" --stderr "$TTY" build/SensorProbe.app --args "$@"
