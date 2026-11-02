

# Aggiornamento del 2 novembre 2026 — Backgammon completato

## Quinto nuovo gioco completato

È stato implementato **Backgammon online per 2 giocatori**.

### Funzioni implementate

- tavoliere standard a 24 punti;
- posizione iniziale classica;
- lancio dei dadi server-side;
- doppio con quattro movimenti disponibili;
- movimento nella direzione corretta per ciascun giocatore;
- controllo dei punti bloccati;
- ingresso obbligatorio dalla barra;
- cattura delle pedine singole e invio alla barra avversaria;
- uscita delle pedine quando sono tutte nella casa;
- vittoria a 15 pedine portate fuori;
- abbandono gestito server-side.

### Nuovi file

```text
supabase/functions/backgammon-move/index.ts
supabase/functions/backgammon-move/backgammon.ts
lib/screens/backgammon_screen.dart
```

Aggiornati anche:

```text
lib/screens/home_screen.dart
lib/screens/lobby_tab.dart
lib/theme.dart
schema.sql
functions_scacchi.sql
```

### Test

I test automatici passano:

```text
Dama: 14 ok
Forza 4 e Tris: 17 ok
Othello: 4 ok
Mulino: 3 ok
Domino: 4 ok
Scopa: 3 ok
Backgammon: 4 ok
Totale: 35 ok, 0 fail
```

### Deploy Supabase

La Edge Function è stata pubblicata:

```text
backgammon-move: HTTP 200
```

### APK Backgammon

[Scarica DuelApp-backgammon.apk](/home/ubuntu/DuelApp-backgammon.apk)

SHA-256:

```text
ad03075535c2f5e2f222d7d4dd75e5f1d60370ffd2cc5b338f1a043903f96d5d
```

### Migrazione cumulativa

[Scarica DuelApp-add-backgammon.sql](/home/ubuntu/DuelApp-add-backgammon.sql)

La migrazione aggiunge o aggiorna Othello, Mulino, Domino, Scopa e Backgammon. Il database remoto deve essere aggiornato eseguendo il file nel SQL Editor Supabase; il nuovo editor ha mostrato un problema di sincronizzazione con l’inserimento automatico, quindi l’esecuzione manuale dal PC resta la procedura affidabile.

### Prossimo gioco

Il prossimo gioco previsto è **Scala 40**, con tavolo massimo da 4 giocatori e banco che trattiene il 20% da ciascun giocatore, come richiesto.


# Avvio Scala 40 — 2 novembre 2026

È stato avviato il motore di Scala 40 con:

- mazzo doppio da 108 carte, inclusi 4 jolly;
- combinazioni tris e scale dello stesso seme;
- calcolo dei punti delle combinazioni;
- apertura obbligatoria a 40 punti;
- calcolo del montepremi per 2, 3 o 4 giocatori;
- trattenuta del banco pari al 20% del totale delle puntate.

Test aggiornati: **39 superati, 0 fallimenti**.

## Nota tecnica importante

L’architettura attuale delle sfide online è ancora basata su due colonne (`player1_id` e `player2_id`) e sulla funzione `accept_challenge` per una sola accettazione. Per rispettare davvero la richiesta di Scala 40 fino a 4 giocatori occorre estendere il modello a una lista di partecipanti, aggiornare RLS, ingresso/uscita dal tavolo, calcolo delle puntate e pagamento al vincitore. Non è stata generata un’APK parziale a 2 giocatori per evitare di consegnare una versione non conforme.

Prossimo passo: completare il tavolo multiplayer Scala 40 e poi produrre APK, deploy Edge Function e migrazione SQL dedicata.
