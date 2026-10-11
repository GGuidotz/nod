#!/bin/zsh
# Compila SensorProbe.app (firma ad hoc, solo per prove locali). Serve: xcode-select --install
set -e
cd "${0:A:h}"
APP=build/SensorProbe.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
swiftc -O -parse-as-library SensorProbe.swift -o "$APP/Contents/MacOS/SensorProbe"
codesign --force --sign - "$APP"
echo "Pronto: $APP"
