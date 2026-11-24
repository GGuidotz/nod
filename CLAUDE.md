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
- Firma con hardened runtime ed entitlement in `Resources/Nod.entitlements` (eventi Apple per l'Updater, calendari per
  Promemoria): da aggiornare se l'app usa una risorsa nuova.
- Il doppio clic del tasto laterale del Watch è sperimentale su macOS 27 (il sistema risponde "annullato"): le
  conferme da lontano passano da ntfy e Promemoria. Vedi README, "Problemi noti".
- ntfy: testo al minimo, token monouso; il token principale non va mai nei pulsanti (solo il "token per i pulsanti",
  Portachiavi `ntfy-reply-token`, da scrittura sola); il topic sta nel Portachiavi (`ntfy-topic`), non nelle preferenze; server proprio descritto in `docs/server-ntfy.md`. Mai segreti, token o testi
  delle richieste nella diagnostica.
- Grafica: Sguardo, il sistema di design comune (github.com/GGuidotz/sguardo, submodule in `Vendor/Sguardo`, regole in
  DESIGN.md e PLAYBOOK.md), compilato insieme all'app da build.sh (`SGUARDO_DIR` per provare il kit locale). Accento
  predefinito `SG.Accent.nod` (#1C9EDB, in `Theme.swift`), applicato con `.sguardoAccent(default:)` in `LanguageRoot`:
  in Impostazioni > Generale la persona sceglie colore dell'app, di sistema o personalizzato (`SGAccentRow`). Pagine con
  `SGPage`/`SGSection`/`SGToggleRow`/`SGMenuRow`, schede con `contentCard`, pulsanti nel contenuto
  `.buttonStyle(.sgSecondary/.sgPrimary/.sgDestructive)`, un solo principale per vista. Liquid Glass solo sui controlli che
  galleggiano (`SGFloatingTabBar` nelle Impostazioni, la capsula dei passi della configurazione), sempre dietro
  `if #available(macOS 26, *)` (`glassSurface` in `Theme.swift`). Stato e colore: il colore non è mai l'unico segnale
  (`NoteLabel`, `StatusRow`). Linee guida HIG in `docs/design-interfaccia.md`. Interfaccia in quattro lingue, niente emoji.
- Repository pubblico: mai dati personali in codice, commenti, esempi o commit.
