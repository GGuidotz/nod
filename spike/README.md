# M0: prove sul Mac (circa 10 minuti)

Quattro prove per verificare sul tuo hardware (AirPods con audio spaziale, Apple Watch, macOS 14+) ciò che il design dà per possibile.
Serve `xcode-select --install` (gli strumenti a riga di comando, gli stessi che usa Cocaine per compilarsi).

```
cd spike
./build.sh
```

Il codice è stato scritto senza poterlo compilare: se `build.sh` dà un errore, apri una issue con l'output.

## 1. Testa e camminata: `./run.sh head`

macOS chiede il permesso *Movimento e fitness* a SensorProbe. Con le AirPods indossate:

1. Toglile e rimettile: devono comparire `DISCONNESSE` / `CONNESSE`.
2. Annuisci 2-3 volte, poi scuoti la testa 2-3 volte, poi inclinala di lato: annota **su quale asse** compare `GESTO` per
   ciascun movimento.
3. Guarda in basso la tastiera e torna su, parla gesticolando: idealmente **nessun** `GESTO` (falsi positivi).
4. Alzati e cammina per la stanza: `CAMMINATA iniziata`. Allontanati finché compare `DISCONNESSE`: a che distanza?
5. Annota la `frequenza` stampata ogni 10 s.

Se i gesti scattano troppo o troppo poco, prova `./run.sh head 2` (più sensibile) o `./run.sh head 4`.

## 2. Conferma col Watch: `./run.sh watch`

Richiede *Sblocca con Apple Watch* attivo (Impostazioni di Sistema > Touch ID e password).

1. Annota le righe `Disponibile ...`.
2. Sul Watch compare la richiesta: premi due volte il tasto laterale. Annota il risultato e i secondi.
3. Ripeti con il Watch in stop (polso abbassato da un po') e con il Watch lontano dal Mac: cosa succede?

## 3. Stelo: `./run.sh stem`, poi `./run.sh stem audio`, poi `./run.sh stem mic`

1. Click singolo, doppio, triplo: compaiono le righe `STELO`?
2. Ripeti con la musica in riproduzione in Musica o Spotify: chi riceve i click, SensorProbe o il lettore?
3. Con `mic`: il click singolo arriva come `gesto muto`? L'audio delle AirPods peggiora (modalità chiamata)?

## 4. ntfy e doppio tap: `./ntfy-probe.sh`

Serve l'app ntfy sull'iPhone, con le notifiche consentite e rispecchiate sul Watch.

1. Iscriviti al topic che lo script stampa, poi premi Invio.
2. Quando la notifica arriva sul Watch, fai doppio tap: lo script stampa `risposta: allow`? Dopo quanti secondi?
3. Rilancia e prova a toccare *Nega* sul Watch: arriva `deny`?
4. Prova col Watch lontano dall'iPhone (solo Wi-Fi) se puoi.

## Cosa annotare

L'output delle quattro prove e le note: assi dei gesti, falsi positivi, distanza di disconnessione,
tempi di conferma, comportamento dello stelo con la musica, doppio tap sì/no.
