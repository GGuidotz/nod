# Nod

Approvazioni a mani libere e presenza per [Cocaine](https://github.com/Mattiakart/cocaine), con AirPods e Apple Watch.
Progetto indipendente, non affiliato a Cocaine.

## Funzioni principali

- **Approvazioni a mani libere, anche lontano dal Mac**: con le AirPods annuisci; dal Watch rispondi Approva o Nega nella
  notifica ntfy, oppure approvi completando il promemoria. **In arrivo**: le richieste vere dell'AI arriveranno quando
  Cocaine aggiungerà il canale per le app companion; oggi le provi con *Prova un'approvazione*.
- **Presenza**: quando ti allontani il Watch ti chiede se tenere sveglio il Mac; senza risposta decide la tua regola.
- **Lingue**: italiano, inglese, francese, spagnolo (Impostazioni > Aspetto > Lingua).
- **Aggiornamenti**: controllo automatico, novità della nuova versione e comando pronto (anche "Aggiorna nel Terminale").
- **Avvisi sul Watch**: notifica ntfy con pulsanti e, se vuoi, avviso nativo di Promemoria (iCloud), senza app da installare.
- **Diagnostica**: report automatico senza segreti, da salvare e allegare a una segnalazione.

## Problemi noti

- **Doppio clic sul tasto laterale del Watch: sperimentale.** Su macOS 27 il sistema chiude la richiesta ma risponde
  "annullato" a ogni app, anche a quelle Apple. È un difetto di macOS/watchOS e aspettiamo un fix da Apple. Intanto rispondi
  dal Watch con la notifica ntfy (Approva o Nega) o approva completando il promemoria. Il doppio clic resta in Diagnostica,
  per riprovarlo dopo un aggiornamento.
- **Il promemoria sa solo approvare.** Per negare usa la notifica ntfy, oppure lascia scadere la richiesta: non succede nulla.

## Requisiti

macOS 14 Sonoma o successivo, AirPods con sensori di movimento (AirPods Pro, AirPods 3 e 4, AirPods Max; facoltative), Apple Watch con iPhone per le
notifiche. Nod è stato provato su macOS 27: sulle versioni precedenti dovrebbe funzionare, ma se trovi problemi
segnalali.

## Autore e segnalazioni

Sviluppato da **gguidotz**: [github.com/GGuidotz/nod](https://github.com/GGuidotz/nod) · giulioguidotz@yahoo.com

Per bug e richieste preferisci le [issue su GitHub](https://github.com/GGuidotz/nod/issues), allegando il report di
Diagnostica (non contiene segreti). L'email resta per tutto il resto.

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

Se così il Watch la riceve e da Nod no, il limite è la firma locale di Nod. Se non la riceve neanche così, è il problema
noto di macOS 27 descritto sopra.

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
| `Sources/ReminderRelay.swift` | Avvisi con Promemoria (lista "Nod" di iCloud), cancellati dopo la risposta |
| `Sources/HeadMotion.swift` | AirPods: indossate, assetto, annuire/scuotere, camminata |
| `Sources/WatchConfirm.swift` | Conferma col tasto laterale del Watch (catena di politiche, prova tramite osascript) |
| `Sources/IconHealth.swift`, `IconMetrics.swift` | Controllo dell'icona del Dock all'avvio e in `build.sh` (`tools/icon-check`) |
| `Sources/ApprovalFlow.swift` | Flusso di un'approvazione (oggi in prova) |
| `Sources/CocaineBridge.swift` | Cocaine tramite la sua riga di comando |
| `packaging/homebrew/Casks/nod.rb` | Il cask per il tap |
| `Sources/Diagnostics.swift`, `DiagnosticsView.swift` | Registro eventi e report di diagnostica |
| `Sources/Updater.swift`, `UpdatesView.swift` | Controllo aggiornamenti e comando per aggiornare |
| `Sources/Localization.swift`, `Localization/` | Lingue (`L("…")`), traduzioni generate da `tools/translations.py` |
