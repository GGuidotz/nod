# Nod

App macOS per la barra dei menu (Swift/SwiftUI, macOS 14+), companion di Cocaine: conferme e presenza con AirPods,
Apple Watch, notifiche ntfy e Promemoria. Progetto indipendente, non affiliato a Cocaine. Stesso schema di
GGuidotz/whats-going-on, GGuidotz/knock e GGuidotz/smartmemo.

- Compilazione: `./build.sh` (swiftc diretto, niente progetto Xcode, `-swift-version 5`, universale arm64 + x86_64).
  `./make-signing-identity.sh` crea una volta l'identità locale in ~/.nod-signing: con la firma ad hoc macOS
  dimentica i permessi a ogni build, e `./build.sh --dmg` la rifiuta. Nel cloud Swift non compila: ogni modifica la
  prova Giulio sul Mac con `./build.sh --install`. Rileggi il codice con cura prima di consegnare.
- Sorgenti in `Sources/` senza sottocartelle (build.sh compila `Sources/*.swift`).
- Testi: chiave = frase italiana, `L("…")`. Lingue: italiano, inglese, francese, spagnolo. Le traduzioni si scrivono in
  `tools/translations.py` (genera `Localization/<lingua>.lproj`), poi `python3 -I tools/check-strings.py`.
- Versione: `VERSION` + sezione `## <versione> · <data>` in cima a `CHANGELOG.md` (build.sh la richiede), in inglese, con
  `### New Features`, `### Improvements`, `### Bug Fixes`, `### Known Issues`.
- Rilascio: `./release.sh` sul Mac di Giulio (DMG, release GitHub, cask in `packaging/homebrew/Casks/nod.rb` e nel tap
  GGuidotz/homebrew-tap). Il cask del repo è la fonte: il tap ne è una copia.
- Il doppio clic del tasto laterale del Watch è sperimentale su macOS 27 (il sistema risponde "annullato"): le
  conferme da lontano passano da ntfy e Promemoria. Vedi README, "Problemi noti".
- ntfy: testo al minimo, token monouso; server proprio descritto in `docs/server-ntfy.md`. Mai segreti, token o testi
  delle richieste nella diagnostica.
- Design: Human Interface Guidelines (`docs/design-interfaccia.md`); colore mai come unico segnale. Interfaccia in
  quattro lingue, niente emoji.
- Repository pubblico: mai dati personali in codice, commenti, esempi o commit.
