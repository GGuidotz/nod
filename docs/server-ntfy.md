# Server ntfy proprio (opt-out da ntfy.sh)

Nod usa **ntfy.sh di default**: funziona subito, ma il gestore di ntfy.sh può leggere il testo delle notifiche e i token dei
pulsanti (ntfy non cifra end-to-end). Nod tiene il testo al minimo e i token valgono una volta sola, per pochi minuti.
Con un server tuo il contenuto non passa più da ntfy.sh. In Nod: *Impostazioni > Notifiche > Server: Server mio*.

## Cosa resta di ntfy.sh, onestamente

iOS consegna le notifiche istantanee solo tramite i server push di Apple, e l'app ntfy dell'App Store li raggiunge solo
attraverso ntfy.sh. Quindi ci sono due livelli di opt-out:

| Configurazione | Cosa vede ntfy.sh | Consegna sull'iPhone |
|---|---|---|
| ntfy.sh (predefinito) | Testo, topic, token dei pulsanti | Istantanea |
| **Server tuo + `upstream-base-url`** (consigliato) | Solo l'id del messaggio e un hash SHA-256 del topic; l'iPhone mostra "New message" se non raggiunge il tuo server | Istantanea |
| Server tuo senza upstream (opt-out totale) | Niente | Da minuti a ore: inutile per le approvazioni |

## Dove ospitarlo

Serve un indirizzo **HTTPS raggiungibile da internet**: l'iPhone lo chiama da ovunque, il Mac anche.

| Opzione | Costo indicativo | Note |
|---|---|---|
| Piccolo VPS (Hetzner, Scaleway, OVH…) | 4-5 €/mese | Il più semplice: Docker + Caddy per l'HTTPS |
| NAS o Raspberry Pi a casa + Cloudflare Tunnel | 0 € | Nessuna porta aperta sul router; dipende dalla connessione di casa |
| NAS o Raspberry Pi + Tailscale Funnel | 0 € | Simile, con Tailscale |

## Installazione (VPS con Docker)

```
mkdir ntfy && cd ntfy
# copia qui server/docker-compose.yml e server/server.yml, poi in server.yml metti il tuo base-url
docker compose up -d

# utente e permessi: solo i topic di Nod
docker compose exec ntfy ntfy user add tuonome                 # chiede la password (per l'app dell'iPhone)
docker compose exec ntfy ntfy access tuonome 'nod-*' rw
docker compose exec ntfy ntfy token add tuonome                # stampa tk_… (per Nod sul Mac)
```

HTTPS con Caddy davanti (file `Caddyfile`):

```
ntfy.esempio.it {
    reverse_proxy 127.0.0.1:8080
}
```

## Collegare Mac e iPhone

1. **Nod**: Impostazioni > Notifiche > *Server mio*, indirizzo `https://ntfy.esempio.it`, token `tk_…`.
2. **iPhone**: ntfy > Impostazioni > *Default server* `https://ntfy.esempio.it`, *Users* aggiungi `tuonome` con la password;
   poi + con il topic che Nod mostra.
3. Nod > Notifiche > *Invia notifica di prova*, doppio tap sul Watch.

Il token finisce nel Portachiavi del Mac e nei pulsanti delle notifiche (che passano solo dal tuo server). Per cambiarlo:
`ntfy token remove`, poi `ntfy token add` e aggiorna Nod.

## Se le notifiche non arrivano sul Watch

Se le vedi nell'elenco dell'app ntfy ma non compaiono come avviso, i messaggi arrivano: manca la consegna push.

1. **iPhone > Impostazioni > Notifiche > ntfy**: Consenti notifiche attivo, Banner, e Avvisi con priorità.
2. **Full immersion**: nessuna attiva che blocchi ntfy (o aggiungi ntfy alle app consentite).
3. **App Watch sull'iPhone > Notifiche > ntfy**: rispecchia gli avvisi dell'iPhone.
4. **Prova con l'iPhone bloccato** e il Watch al polso, sbloccato: il Watch mostra le notifiche solo quando l'iPhone è
   bloccato (se lo stai usando, l'avviso resta sull'iPhone).
5. **Andata e ritorno**: Nod > Notifiche > *Invia prova*, poi tocca *Ricevuta*. Se Nod scrive "Risposta ricevuta dal Watch",
   il percorso dei pulsanti funziona e resta solo da sistemare la visualizzazione (punti 1-4).
6. Con un **server tuo**, senza `upstream-base-url` l'iPhone riceve le notifiche con molto ritardo.

Le approvazioni e "Ti stai allontanando" partono con priorità massima (5); la prova con priorità alta (4).
