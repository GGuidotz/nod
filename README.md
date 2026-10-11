# Nod

Approvazioni a mani libere e presenza per [Cocaine](https://github.com/Mattiakart/cocaine), con AirPods e Apple Watch.
Progetto indipendente, non affiliato a Cocaine.

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

Il codice è stato scritto senza poterlo compilare (ambiente Linux): la prima build potrebbe segnalare errori da sistemare.

## Pubblicare una versione

Una volta sola:

1. I repo esistono già: **`GGuidotz/nod`** (codice e release con i DMG) e **`GGuidotz/homebrew-tap`** (il cask; il nome
   deve iniziare con `homebrew-`: è così che `gguidotz/tap/nod` lo trova).
2. Clona il tap: `git clone https://github.com/GGuidotz/homebrew-tap ~/Developer/homebrew-tap` (o imposta `NOD_TAP_DIR`).
3. `brew install gh && gh auth login`.

A ogni versione:

1. Aumenta `VERSION` e aggiungi in cima a `CHANGELOG.md` la sezione `## <versione> · <data>` con una riga per novità.
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
| `Sources/WatchConfirm.swift` | Conferma col tasto laterale del Watch |
| `Sources/ApprovalFlow.swift` | Flusso di un'approvazione (oggi in prova) |
| `Sources/CocaineBridge.swift` | Cocaine tramite la sua riga di comando |
| `packaging/homebrew/Casks/nod.rb` | Il cask per il tap |
