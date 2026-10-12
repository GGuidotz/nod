# Nod

Approvazioni a mani libere e presenza per [Cocaine](https://github.com/Mattiakart/cocaine), con AirPods e Apple Watch.
Progetto indipendente, non affiliato a Cocaine.

## Funzioni principali

- **Approvazioni a mani libere**: con le AirPods annuisci e confermi col tasto laterale del Watch; senza AirPods basta il Watch.
- **Presenza**: quando ti allontani il Watch ti chiede se tenere sveglio il Mac; senza risposta decide la tua regola.
- **Lingue**: italiano, inglese, francese, spagnolo (Impostazioni > Aspetto > Lingua).
- **Aggiornamenti**: controllo automatico, novità della nuova versione e comando pronto (anche "Aggiorna nel Terminale").
- **Diagnostica**: report automatico senza segreti, da salvare e allegare a una segnalazione.

## Autore

Sviluppato da **gguidotz**: [github.com/GGuidotz/nod](https://github.com/GGuidotz/nod) · giulioguidotz@yahoo.com

## Installazione (per chi la usa)

```
brew install --cask gguidotz/tap/nod
```

Homebrew scarica il DMG dalla release, copia Nod in Applicazioni e toglie la quarantena (l'app non è notarizzata), quindi
niente "Apri comunque". Al primo avvio si apre la configurazione guidata. Aggiornare: `brew upgrade --cask nod` (dopo
l'aggiornamento Nod mostra le novità). Disinstallare: `brew uninstall --cask nod` (`--zap` cancella anche le preferenze).

## Compilare (per chi sviluppa)

Servono macOS 14+ e gli strumenti a riga di comando (`xcode-select --install`); niente progetto Xcode, come Cocaine.

```
./make-signing-identity.sh   # una volta: firma stabile, così macOS non dimentica i permessi a ogni build
./build.sh --install         # compila, firma, copia in /Applications e apre
```

Con Xcode installato, `build.sh` compila anche l'icona Liquid Glass (`Resources/Icon/Nod.icon`, formato Icon Composer) e la
controlla disegnandola come il Dock (`tools/icon-check`): se risulta vuota usa l'icona classica
(`Resources/Icon/AppIcon-1024.png`, generata da `tools/render-icon.py`) e lascia le anteprime in `build/icon-preview.png` e
`build/icon-actool.png`. Senza Xcode, icona classica.

## Se il Watch non riceve la richiesta

Diagnostica > *Prova il Watch tramite osascript* fa la stessa richiesta da un processo firmato Apple. Dal Terminale:

```
xcrun swift tools/watch-probe.swift          # solo Watch
xcrun swift tools/watch-probe.swift both     # Touch ID o Watch
```

Se così il Watch la riceve e da Nod no, il limite è la firma locale di Nod; intanto Nod usa Touch ID.

## Pubblicare una versione

Una volta sola:

1. I repo esistono già: **`GGuidotz/nod`** (codice e release con i DMG) e **`GGuidotz/homebrew-tap`** (il cask; il nome
   deve iniziare con `homebrew-`: è così che `gguidotz/tap/nod` lo trova).
2. Clona il tap: `git clone https://github.com/GGuidotz/homebrew-tap ~/Developer/homebrew-tap` (o imposta `NOD_TAP_DIR`).
3. `brew install gh && gh auth login`.

A ogni versione:

1. Aumenta `VERSION` e aggiungi in cima a `CHANGELOG.md` la sezione `## <versione> · <data>` (in inglese, con `### New Features`,
   `### Improvements`, `### Bug Fixes`, `### Known Issues`). Le traduzioni: `python3 tools/translations.py` e `tools/check-strings.py`.
2. Fai il commit, poi `./release.sh`: crea il DMG firmato, la release `v<versione>` con il DMG e le note del changelog,
   aggiorna `version` e `sha256` del cask e lo pubblica nel tap.

È lo stesso schema di Cocaine (`mattiakart/tap/cocaine`): release GitHub con il DMG, un cask nel tap che punta alla release,
quarantena tolta all'installazione.

## Documentazione

- [Server ntfy proprio](docs/server-ntfy.md): come uscire da ntfy.sh, con configurazione Docker pronta in `server/`.
- [Scelte di design dell'interfaccia](docs/design-interfaccia.md), secondo le Human Interface Guidelines di Apple.
- [Prove sui sensori](spike/README.md): AirPods, Apple Watch, stelo, notifiche.

Licenza MIT.

## Struttura

| File | Cosa fa |
|---|---|
| `Sources/NodApp.swift` | Scene: finestra, Impostazioni, icona nella barra dei menu, comandi |
| `Sources/AppModel.swift` | Stato dell'app, quando mostrare configurazione e novità |
| `Sources/Setup.swift` | Configurazione guidata; `introducedIn` per mostrare solo i passaggi nuovi dopo un aggiornamento |
| `Sources/Changelog.swift` | Novità lette da `CHANGELOG.md` incluso nell'app |
| `Sources/PresenceEngine.swift` | In uscita / lontano / al Mac, proposta sul Watch, regola senza risposta |
| `Sources/Preferences.swift` | Preferenze e regola di presenza (app, giorni, fascia oraria) |
| `Sources/NotificationRelay.swift` | ntfy: notifiche con pulsanti, token monouso, ascolto delle risposte |
| `Sources/HeadMotion.swift` | AirPods: indossate, assetto, annuire/scuotere, camminata |
| `Sources/WatchConfirm.swift` | Conferma col tasto laterale del Watch (catena di politiche, prova tramite osascript) |
| `Sources/IconHealth.swift`, `IconMetrics.swift` | Controllo dell'icona del Dock all'avvio e in `build.sh` (`tools/icon-check`) |
| `Sources/ApprovalFlow.swift` | Flusso di un'approvazione (oggi in prova) |
| `Sources/CocaineBridge.swift` | Cocaine tramite la sua riga di comando |
| `packaging/homebrew/Casks/nod.rb` | Il cask per il tap |
| `Sources/Diagnostics.swift`, `DiagnosticsView.swift` | Registro eventi e report di diagnostica |
| `Sources/Updater.swift`, `UpdatesView.swift` | Controllo aggiornamenti e comando per aggiornare |
| `Sources/Localization.swift`, `Localization/` | Lingue (`L("…")`), traduzioni generate da `tools/translations.py` |
