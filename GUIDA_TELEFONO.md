# Guida: tutto dal telefono (Android), senza computer

Idea: GitHub (gratis) compila l'app e pubblica le funzioni al posto tuo. Tu usi solo il browser.

## A. Supabase (browser)
1. supabase.com > crea un progetto gratuito.
2. SQL Editor: incolla ed esegui, uno alla volta e in quest'ordine: `schema.sql`, `functions.sql`, `functions_scacchi.sql`, `functions_maintenance.sql`, `functions_profile.sql`.
3. Authentication > Providers > Email: disattiva **Confirm email**.
4. Annota: **Project URL**, chiave **anon public** (Settings > API) e **Project ref** (la parte iniziale dell'URL, prima di `.supabase.co`).
5. Account (icona profilo) > Access Tokens > crea un token: e' il tuo `SUPABASE_ACCESS_TOKEN`.

## B. GitHub (browser, meglio con "Sito desktop")
1. github.com > crea account gratuito > **New repository** (privato va bene).
2. **Add file > Upload files**: decomprimi `duelapp.zip` sul telefono (app File) e carica **tutto il contenuto della cartella `duelapp`**, comprese le cartelle nascoste `.github`. Se il telefono non carica le cartelle nascoste, crea a mano il file `.github/workflows/build.yml` con "Create new file" incollando il contenuto.
3. Repo > **Settings > Secrets and variables > Actions > New repository secret**. Crea 4 secret:
   `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`.

## C. Pubblica le funzioni
Repo > **Actions > Deploy Edge Functions > Run workflow**. A fine run, apri il run e leggi il riepilogo: deve mostrare 4 deploy riusciti.

## D. Compila l'app
Repo > **Actions > Build APK > Run workflow**. Dopo qualche minuto apri il run:
- in fondo c'e' **Artifacts > duelapp-apk**: scaricalo, estrai l'APK e installalo (permetti "installa da fonti sconosciute").
- se il run e' rosso, apri il riepilogo (Summary) e **copia il testo** degli errori qui in chat.
