# Interfaccia di Nod: scelte di design

Progettata con le Human Interface Guidelines di Apple (pagine aggiornate al 2026). Ogni scelta cita la pagina.

## Tesi

Nod è un'utility silenziosa: vive nella barra dei menu e si fa vedere solo quando serve una decisione. La finestra serve a
configurare, controllare lo stato e provare. **L'elemento per cui si ricorda**: le AirPods disegnate che seguono la tua testa in
tempo reale (`HeadIndicator`), nella configurazione e in Dispositivi. Non è decorazione: dimostra che il sensore funziona ed è
lo stesso gesto con cui approvi. Tutto il resto è sistema: SF Pro, colori semantici, controlli standard.

## Struttura

| Parte | Scelta | Riferimento |
|---|---|---|
| Barra dei menu | Un **menu** (non un popover): presenza, "Sto uscendo / Sono al Mac", Cocaine, prova, Apri, Impostazioni, Esci. Simbolo SF che cambia con la presenza | `the-menu-bar.md › Menu bar extras`: "Display a menu — not a popover — when people click your menu bar extra." |
| Finestra | `NavigationSplitView`, 5 voci a un livello: Stato, Approvazioni, Presenza, Dispositivi, Novità. Niente in fondo alla barra laterale | `sidebars.md › Best practices` (max due livelli), `sidebars.md › Desktop`: "Avoid putting critical information or actions at the bottom of a sidebar." |
| Impostazioni | Finestra standard (⌘,) con due pannelli: Generale, Notifiche. Solo ciò che si cambia di rado (server, accesso, voce) | `settings.md › Desktop (macOS)`; `settings.md › General settings` |
| Regola di presenza | Nella sezione Presenza, non nelle Impostazioni: è un'opzione del compito | `settings.md › Task-specific options` |
| Comandi | Ogni azione anche nella barra dei menu: menu *Presenza*, *Novità…* e *Ripeti configurazione…* nel menu dell'app | `designing-for-macos.md › Best practices`: "Use the menu bar to give people easy access to all the commands" |

## Configurazione e Novità

| Scelta | Riferimento |
|---|---|
| Breve, saltabile dal primo passo (*Configura più tardi*), riapribile da *Nod > Ripeti configurazione* | `onboarding.md › Best practices`: "design a flow that's fast, fun, and optional" e "make sure it's easy for people to find if they want to view it later" |
| Ogni passaggio si prova: annuire con l'indicatore dal vivo, conferma vera sul Watch, notifica vera sul telefono | `onboarding.md`: "Teach through interactivity." |
| Il permesso Movimento si chiede nel passaggio AirPods, con una schermata e un solo pulsante *Continua* che apre la richiesta di sistema | `privacy.md › Pre-alert screens`: "Include only one button and make it clear that it opens the system alert" e titolo come "Continue" |
| Testo della richiesta di permesso attivo e specifico ("Nod legge il movimento della testa dalle AirPods per riconoscere quando annuisci…") | `privacy.md › Requesting permission` |
| Impostazioni predefinite sensate (ntfy.sh, Teams, lun-ven 9-18): si può usare l'app senza toccare nulla | `onboarding.md › Additional requests`: "Provide reasonable default settings" |
| Dopo un aggiornamento: Novità e solo i passaggi nuovi (`introducedIn`), non l'intera configurazione | Scelta nostra, coerente con `onboarding.md` (non ripresentare ciò che è già stato visto) |
| Nessuna licenza o pubblicità nel flusso | `onboarding.md › Additional content` |

## Accessibilità

- Stati scritti sempre in parole con simbolo: il colore (verde/arancione) non è mai l'unico segnale (`StatusRow`).
- Riduci movimento: l'indicatore resta fermo e mostra i gradi in testo.
- I giorni della settimana hanno etichette VoiceOver complete ("lunedì", non "L").
- Tutto si usa da tastiera: *Continua* è l'azione predefinita (Invio). Nessuna scorciatoia personalizzata per ora: ⌥⌘H è già *Nascondi altre* di sistema.
- Testi con dimensioni di sistema (titolo `largeTitle`, corpo predefinito 13 pt), nessun peso sottile.

## Testi

- Le etichette dicono cosa succede: *Invia notifica di prova*, *Prova la conferma*, *Inizia a usare Nod*.
- La regola di presenza si legge come una frase sotto i controlli, che cambia mentre la modifichi.
- Gli errori dicono cosa fare: "Attiva Impostazioni di Sistema > Touch ID e password > Apple Watch, poi riprova."
- Onestà sui limiti: "Le richieste vere dell'AI non sono ancora collegate a Cocaine…", "Su ntfy.sh il gestore del servizio può leggere il testo…".

## Da fare quando l'app gira

- Icona dell'app (strati per chiaro, scuro e colorata: `app-icons.md`).
- Controllo dal vivo di contrasti e dimensioni in chiaro, scuro e Aumenta contrasto.
- Revisione di design sugli screenshot reali.
