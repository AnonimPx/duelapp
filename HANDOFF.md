# DuelApp - HANDOFF

Documento per riprendere il lavoro (in una nuova chat o con un altro sviluppatore).

## 1. Cos'e' DuelApp
Game Center 1vs1: registrazione, profilo (livello, XP, ELO globale), wallet in Gemme, bacheca sfide live con puntata, 4 giochi.
Stack: Flutter + Supabase (Postgres, Auth, Realtime) + Edge Functions (Deno/TypeScript).
Principio: **il client non decide mai nulla**. Mosse e vincitore sono validati dal server; ogni movimento di Gemme e' una funzione SQL atomica che scrive una transazione con saldo prima/dopo.

## 2. Stato attuale (costruito)
| Area | Stato |
|---|---|
| Schema DB + RLS (client solo lettura) | fatto (`schema.sql`) |
| Wallet atomico: crea/annulla/accetta sfida, scadenza, chiusura partita, ELO +15/-15, XP, fee 20% | fatto (`functions.sql`), **provato su Postgres 16 reale** (vedi sotto) |
| Chiusura automatica partite ferme (10 min senza mossa: perde chi doveva muovere) | fatto (`functions_maintenance.sql`), provato su Postgres; il cron va attivato a mano |
| Profilo ricco: avatar (16 emoji x 8 colori), nick modificabile e univoco (anche con maiuscole diverse), barra livello/XP con titolo, statistiche totali (partite, vittorie, %, miglior serie) e per gioco (ELO, V/S/P, serie), storico con nome del gioco | fatto (`functions_profile.sql`, `lib/avatars.dart`, `edit_profile_screen.dart`, `profile_tab.dart`); SQL provato su Postgres, schermate Flutter non compilate |
| Dama (server-autoritativa) | fatto, logica testata in locale |
| Forza 4 | fatto, logica testata in locale |
| Tris Pro (variante: max 3 segni, sparisce il piu' vecchio; patta dopo 60 mosse) | fatto, logica testata in locale |
| Scacchi via Lichess (open challenge anonima, risultato letto da `game/export`) | scritto, **mai provato contro Lichess** |
| App Flutter: auth, profilo+wallet+storico, bacheca realtime, 4 schermate di gioco | scritta, **mai compilata ne' eseguita** |
| **v0.2** Grafica rifatta: tema scuro viola/ciano (`theme.dart`), scacchiere dipinte con `CustomPainter` (Dama in legno con dame dorate, Forza 4 con plancia forata e caduta animata, Tris al neon), schede giocatore, fine partita con coriandoli, bacheca con sheet "Nuova sfida", profilo ridisegnato | scritta, **mai compilata** |
| **v0.2** Audio: 11 effetti WAV generati (`tools/make_sounds.py`), vibrazione, mute salvato (`lib/audio.dart`) | scritto, **mai eseguito** |
| **v0.2** Connessione: banner offline, stream che si riconnettono (`resilient`), rilettura ogni 4 s e al ritorno in primo piano (`lib/connection.dart`, `GameShell`) | scritto, **mai eseguito** |
| **v0.2** Nuove schermate: Classifica (globale e per gioco), regole per gioco, reset password, avviso di configurazione mancante | scritte, **mai compilate** |
| **v0.2** Dama: presa maggioritaria e pareggi (80 semimosse di sole dame senza prese, o stessa posizione 3 volte) | fatto |
| **v0.3** Dama: spareggio per qualita' (a pari pezzi: prende la dama; poi piu' dame catturate; poi dama catturata per prima) e pezzi catturati tolti a fine mossa (non si saltano due volte, la dama puo' ripassare dalla casa di partenza) | fatto, **14 controlli con Node** (`tests/dama_test.ts`, lanciati da `run_all.sh`) e `tsc --strict`; non provato su Deno/Supabase |
| Gemme di test (1000 al signup, +500 se sotto 100) | fatto |

**Cosa e' stato davvero provato**: tutti gli SQL (`schema.sql`, `functions.sql`, `functions_scacchi.sql`, `functions_maintenance.sql`, `functions_profile.sql`) girano senza errori su un Postgres 16 locale con uno stub minimo di Supabase (schema `auth`, ruoli, publication). Lo scenario in `tests/scenario.sql` verifica: bonus iniziale, sfida non accettabile da chi la crea, premio/fee/ELO/XP, `finish_match` idempotente, rimborso su annullamento, chiusura partita ferma, permesso negato a `authenticated` su `finish_match`, e che le Gemme totali restino invariate (nessuna perdita). `tests/profile_scenario.sql` verifica statistiche per gioco (vittorie, sconfitte, pareggi, serie, ELO per gioco), nick liberi/occupati (anche maiuscole), avatar e colori non validi. Per rilanciare tutto: `bash tests/run_all.sh` (serve Postgres locale, come root).
**Controllo statico (ultimo giro)**: le Edge Function passano `tsc --strict` (con `verbatimModuleSyntax`), corretti 3 import di tipi (`import { type Side }`); parentesi bilanciate in tutti i file Dart; `typedef Rows` spostato in `lib/supa.dart`; aggiunti `dev_dependencies` (flutter_test, flutter_lints) e `analysis_options.yaml`; README: serve cancellare `test/widget_test.dart` dopo `flutter create` (altrimenti errore su `MyApp`) e `INTERNET` nel manifest principale per le build release.
**Controllo statico v0.3**: import Dart coerenti tra i file (nessun simbolo di `theme.dart` usato senza import), versione app 0.3.0+3.
**Test Node aggiuntivi**: `tests/f4_tris_test.ts` (17 controlli su Forza 4 e Tris Pro, passano), lanciati da `run_all.sh`.
**Da telefono (v0.3)**: `GUIDA_TELEFONO.md` + workflow GitHub Actions (`.github/workflows/build.yml` compila l'APK ed esegue i test Node; `deploy-functions.yml` pubblica le 4 Edge Function). I workflow non sono mai stati eseguiti: il primo run reale puo' rivelare errori nel workflow stesso.
**Non provato**: le Edge Function su Supabase/Deno, l'app Flutter (mai compilata), l'integrazione Lichess. Il primo avvio vero dara' probabilmente qualche errore da sistemare.

## 3. Mappa dei file
- `schema.sql`, `functions.sql`, `functions_scacchi.sql`, `functions_maintenance.sql` (`functions_forza4.sql` e `functions_tris.sql` sono superati dal cumulativo)
- `functions_profile.sql` - avatar, statistiche per gioco, `update_profile`, `check_username`; **sostituisce `finish_match`** (ora aggiorna anche le statistiche)
- `tests/` - `bootstrap.sql`, `scenario.sql`, `profile_scenario.sql`, `run_all.sh`: test SQL su Postgres puro
- `lib/avatars.dart` (liste avatar/colori, titoli di livello: devono coincidere con `update_profile`), `lib/screens/edit_profile_screen.dart`
- `supabase/functions/{dama-move,forza4-move,tris-move,scacchi-lichess}/` - un arbitro per gioco; ognuno ha `index.ts` (+ file di logica pura `dama.ts`, `forza4.ts`, `tris.ts`)
- `lib/main.dart`, `lib/supa.dart` (client + messaggi errore), `lib/screens/*` (auth, home, profile_tab, lobby_tab, leaderboard_tab, una schermata per gioco)
- `lib/theme.dart` (palette, `GlassCard`, `GemChip`, `gameStyle`), `lib/widgets.dart` (`GameShell`, `PlayerCard`, `ResultOverlay`, `toast`), `lib/audio.dart`, `lib/connection.dart`; `assets/audio/*.wav`, `tools/make_sounds.py`
- Per aggiungere un gioco: ramo in `initial_game_data` (SQL), nuova Edge Function, nuova schermata basata su `GameShell` (passi `fn`, `isMyTurn`, colori e `boardBuilder`), riga in `home_screen.dart` (switch sullo slug) e in `lobby_tab.dart` (giochi selezionabili), stile in `gameStyle` (theme.dart).

## 4. BLOCCANTE prima di usare soldi veri
Il modello "compro Gemme, punto, vinco, riscatto Buoni" **non e' un concorso a premi (DPR 430/2001)**: li' la partecipazione e' gratuita e il montepremi lo mette il promotore. Con puntate pagate dagli utenti e vincite in valore reale ricade nei giochi con vincita in denaro, che in Italia richiedono concessione ADM (societa' di capitali, requisiti patrimoniali) o una partnership con un concessionario. Servono anche le regole degli store (Apple/Google) sui premi reali.
Strade legali valutate: (1) licenza/partner ADM, (2) free-to-play con Gemme solo cosmetiche, (3) concorso a premi vero con tornei/classifiche gratuiti e premi pagati da te. Fare validare da un **legale gaming**, non solo dal commercialista.
Per il test con amici: solo Gemme virtuali, nessun denaro in ingresso o in uscita.

## 5. Cosa manca (in ordine di priorita')
1. **Primo avvio vero**: eseguire gli SQL, deployare le 4 funzioni, `flutter run`, correggere gli errori. Provare ogni gioco con 2 account.
2. **Scacchi - da verificare su Lichess**: (a) l'id della sfida coincide con l'id della partita; (b) formato di `game/export/{id}` (campi `status`, `winner`); (c) forma della risposta di `challenge/open`. Limite noto: i link sono anonimi, quindi chi li ha puo' barare (stesso giocatore su entrambi i lati, aiuti esterni); i due link stanno in `game_data` leggibile da entrambi. Soluzione robusta: account Lichess collegati via OAuth o Board API.
3. **Dama**: completa (v0.3). Il client lascia scegliere il percorso e il server lo valida; i nuovi errori possibili sono gia' coperti da `must_capture_max`/`must_continue_capture` in `supa.dart` (verificare che i messaggi siano chiari al primo avvio).
4. **Anti-abuso**: collusione tra due account propri, multi-account, rate limiting delle Edge Functions, verifica maggiore eta' (18+) e controlli di gioco responsabile se mai ci saranno soldi veri.
5. **Attivare il cron**: abilitare pg_cron in Supabase (Database > Extensions) e lanciare le 2 righe `cron.schedule` in fondo a `functions_maintenance.sql`. Gli Scacchi restano fuori dalla chiusura automatica (decide Lichess): se i giocatori non premono "Aggiorna" il risultato si legge solo mentre la schermata e' aperta; idea: pg_cron + pg_net che chiama `scacchi-lichess` con `sync` per le partite aperte.
6. **Economia**: bonus giornaliero con AdMob, shop premi e riscatto (`rewards`), acquisto Gemme (Stripe/RevenueCat), wallet `bonus/redeemable` con rollover x3. Tutto rimosso volutamente dal test; dipende dalla decisione legale del punto 4.
7. **Prodotto**: (classifica, regole e reset password fatti in v0.2; per il reset serve configurare l'URL di redirect in Supabase) profili degli altri giocatori (le statistiche sono gia' leggibili da tutti), badge/obiettivi, avatar con foto, matchmaking, notifiche push, reset password, schermata regole, pulizia UI, test automatici Dart.
8. **Sicurezza**: ripassare le policy RLS prima di aprire a utenti esterni; in produzione riattivare "Confirm email".

## 6. Decisioni da ricordare
- Fee piattaforma 20% del piatto, fissa in `accept_challenge` (`v_fee`). ELO +/-15 e XP +10/+3 in `finish_match`.
- `functions_profile.sql` aggiunge il vincolo `username_format` (solo lettere, numeri, `_`): su un database con nick gia' esistenti di altro formato va corretto prima. Il livello e' 1 + XP/100; titoli: Novizio, Sfidante (liv. 2), Veterano (5), Maestro (10), Leggenda (20).
- Puntata minima 10 Gemme, scadenza sfida 30 minuti, max 3 sfide aperte per utente.
- `finish_match` e' chiamabile solo con service role (Edge Function). Pareggio/annullamento = puntate restituite, nessuna fee.
- Il giocatore che crea la sfida e' player1 (bianco / rosso / X).
- Concorrenza sulle mosse: aggiornamento ottimistico sul contatore `moves`.

## 7. Come lavora Adam
Passi piccoli e incrementali: una modifica per volta, output validato prima di andare avanti. Preferisce ricevere **solo i file modificati**; in questo progetto ha pero' chiesto esplicitamente, **a fine di ogni lavoro: handoff aggiornato + zip completo aggiornato**.

## 8. Prompt per riprendere
> Riprendo DuelApp (Flutter + Supabase). Leggi HANDOFF.md e README.md allegati. Stato: tutto scritto ma mai eseguito (v0.2: grafica, audio, connessione, classifica, Dama completa). Serve Flutter >= 3.27. Iniziamo dal punto 1 di "Cosa manca": ti incollo gli errori del primo avvio, correggili uno alla volta consegnandomi solo i file modificati.
