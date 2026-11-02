-- DuelApp database setup: eseguire tutto in una sola query Supabase.
-- 1) Schema
-- DuelApp - schema v1 (TEST INTERNO: Gemme virtuali, nessun acquisto, nessun riscatto)
-- Esegui in Supabase > SQL Editor.

-- ========== TABELLE ==========

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (char_length(username) between 3 and 20),
  level int not null default 1,
  xp int not null default 0,
  elo_global int not null default 1000,
  created_at timestamptz not null default now()
);

create table public.wallets (
  user_id uuid primary key references public.users(id) on delete cascade,
  balance_gems int not null default 0 check (balance_gems >= 0),
  hold_gems int not null default 0 check (hold_gems >= 0),
  updated_at timestamptz not null default now()
);

create table public.games (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  type text not null check (type in ('internal', 'external_api')),
  is_active boolean not null default true
);

insert into public.games (slug, name, type) values
  ('dama', 'Dama Italiana', 'internal'),
  ('forza4', 'Forza 4', 'internal'),
  ('tris_pro', 'Tris Pro', 'internal'),
  ('scacchi', 'Scacchi Rapidi', 'external_api');

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.users(id),
  game_id uuid not null references public.games(id),
  stake_gems int not null check (stake_gems >= 10),
  status text not null default 'open' check (status in ('open', 'accepted', 'expired', 'cancelled')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 minutes'
);

create index challenges_open_idx on public.challenges (status, expires_at);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null unique references public.challenges(id),
  game_id uuid not null references public.games(id),
  player1_id uuid not null references public.users(id),
  player2_id uuid not null references public.users(id),
  stake_gems int not null check (stake_gems > 0),
  fee_gems int not null check (fee_gems >= 0),
  prize_gems int not null check (prize_gems >= 0),
  winner_id uuid references public.users(id),
  status text not null default 'in_progress'
    check (status in ('in_progress', 'finished', 'cancelled')),
  game_data jsonb not null default '{}',
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  check (player1_id <> player2_id),
  check (prize_gems + fee_gems = stake_gems * 2),
  check (winner_id is null or winner_id in (player1_id, player2_id))
);

create index matches_players_idx on public.matches (player1_id, player2_id);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  match_id uuid references public.matches(id),
  type text not null check (type in
    ('test_grant', 'stake_hold', 'stake_release', 'win', 'fee_platform')),
  amount_gems int not null,
  balance_before int not null,
  balance_after int not null,
  created_at timestamptz not null default now()
);

create index transactions_user_idx on public.transactions (user_id, created_at desc);

-- ========== SIGNUP: profilo + wallet + 1000 Gemme di test ==========

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_username text;
begin
  v_username := coalesce(
    nullif(new.raw_user_meta_data ->> 'username', ''),
    'player_' || substr(new.id::text, 1, 8)
  );

  insert into public.users (id, username) values (new.id, v_username);
  insert into public.wallets (user_id, balance_gems) values (new.id, 1000);
  insert into public.transactions (user_id, type, amount_gems, balance_before, balance_after)
  values (new.id, 'test_grant', 1000, 0, 1000);

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ========== RLS: il client legge soltanto, scrive solo il server ==========

alter table public.users enable row level security;
alter table public.wallets enable row level security;
alter table public.games enable row level security;
alter table public.challenges enable row level security;
alter table public.matches enable row level security;
alter table public.transactions enable row level security;

create policy "users_select_all" on public.users
  for select to authenticated using (true);

create policy "wallets_select_own" on public.wallets
  for select to authenticated using (user_id = auth.uid());

create policy "games_select_all" on public.games
  for select to authenticated using (true);

create policy "challenges_select_all" on public.challenges
  for select to authenticated using (true);

create policy "matches_select_participant" on public.matches
  for select to authenticated
  using (auth.uid() in (player1_id, player2_id));

create policy "transactions_select_own" on public.transactions
  for select to authenticated using (user_id = auth.uid());

-- Nessuna policy di insert/update/delete: tutte le scritture passano da
-- funzioni SQL security definer o Edge Functions con service role (step successivi).

-- ========== REALTIME per la bacheca sfide ==========

alter publication supabase_realtime add table public.challenges;

-- 2) Funzioni wallet e partite
-- DuelApp - funzioni v1 (step 2). Esegui DOPO schema.sql.
-- Tutte le operazioni sul wallet sono atomiche e creano una transazione.

create table if not exists public.platform_fees (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null unique references public.matches(id),
  fee_gems int not null,
  created_at timestamptz not null default now()
);
alter table public.platform_fees enable row level security;

-- ---------- helper interni ----------

create or replace function public.initial_game_data(p_slug text)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare v_board text;
begin
  if p_slug = 'dama' then
    -- 64 caratteri, riga 0 in alto. w/b = pedine, W/B = dame, . = vuoto
    select string_agg(
      case when (r + c) % 2 = 1
        then case when r <= 2 then 'b' when r >= 5 then 'w' else '.' end
        else '.' end, '' order by r, c)
    into v_board
    from generate_series(0, 7) r, generate_series(0, 7) c;
    return jsonb_build_object('board', v_board, 'turn', 'w', 'moves', 0,
      'last_move_at', (extract(epoch from now()) * 1000)::bigint, 'last_move', null);
  end if;
  return '{}'::jsonb;
end $$;

create or replace function public._release_stake(p_user uuid, p_stake int, p_match uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_bal int;
begin
  select balance_gems into v_bal from public.wallets where user_id = p_user for update;
  update public.wallets
    set hold_gems = hold_gems - p_stake, balance_gems = balance_gems + p_stake, updated_at = now()
    where user_id = p_user;
  insert into public.transactions (user_id, match_id, type, amount_gems, balance_before, balance_after)
  values (p_user, p_match, 'stake_release', p_stake, v_bal, v_bal + p_stake);
end $$;

-- ---------- API client ----------

create or replace function public.create_challenge(p_game_id uuid, p_stake int)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_bal int; v_id uuid; v_open int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_stake < 10 then raise exception 'stake_too_low'; end if;
  perform 1 from public.games where id = p_game_id and is_active;
  if not found then raise exception 'game_not_available'; end if;

  select balance_gems into v_bal from public.wallets where user_id = v_uid for update;
  if v_bal < p_stake then raise exception 'insufficient_funds'; end if;

  select count(*) into v_open from public.challenges
    where creator_id = v_uid and status = 'open' and expires_at > now();
  if v_open >= 3 then raise exception 'too_many_open_challenges'; end if;

  update public.wallets
    set balance_gems = balance_gems - p_stake, hold_gems = hold_gems + p_stake, updated_at = now()
    where user_id = v_uid;
  insert into public.challenges (creator_id, game_id, stake_gems)
    values (v_uid, p_game_id, p_stake) returning id into v_id;
  insert into public.transactions (user_id, type, amount_gems, balance_before, balance_after)
    values (v_uid, 'stake_hold', -p_stake, v_bal, v_bal - p_stake);
  return v_id;
end $$;

create or replace function public.cancel_challenge(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); c public.challenges;
begin
  select * into c from public.challenges where id = p_id for update;
  if not found or c.creator_id is distinct from v_uid then raise exception 'challenge_not_found'; end if;
  if c.status <> 'open' then raise exception 'challenge_not_available'; end if;
  perform public._release_stake(c.creator_id, c.stake_gems);
  update public.challenges set status = 'cancelled' where id = c.id;
end $$;

create or replace function public.accept_challenge(p_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid(); c public.challenges;
  v_bal int; v_fee int; v_prize int; v_match uuid; v_slug text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into c from public.challenges where id = p_id for update;
  if not found then raise exception 'challenge_not_found'; end if;
  if c.status <> 'open' or c.expires_at <= now() then raise exception 'challenge_not_available'; end if;
  if c.creator_id = v_uid then raise exception 'cannot_accept_own_challenge'; end if;

  select balance_gems into v_bal from public.wallets where user_id = v_uid for update;
  if v_bal < c.stake_gems then raise exception 'insufficient_funds'; end if;

  update public.wallets
    set balance_gems = balance_gems - c.stake_gems, hold_gems = hold_gems + c.stake_gems, updated_at = now()
    where user_id = v_uid;
  insert into public.transactions (user_id, type, amount_gems, balance_before, balance_after)
    values (v_uid, 'stake_hold', -c.stake_gems, v_bal, v_bal - c.stake_gems);

  v_fee := (c.stake_gems * 2 * 20) / 100;      -- fee piattaforma 20% del piatto
  v_prize := c.stake_gems * 2 - v_fee;
  select slug into v_slug from public.games where id = c.game_id;

  update public.challenges set status = 'accepted' where id = c.id;
  insert into public.matches
    (challenge_id, game_id, player1_id, player2_id, stake_gems, fee_gems, prize_gems, game_data)
  values (c.id, c.game_id, c.creator_id, v_uid, c.stake_gems, v_fee, v_prize,
          public.initial_game_data(v_slug))
  returning id into v_match;
  return v_match;
end $$;

create or replace function public.expire_stale_challenges()
returns void language plpgsql security definer set search_path = '' as $$
declare c public.challenges;
begin
  for c in select * from public.challenges
           where status = 'open' and expires_at <= now() for update skip locked
  loop
    perform public._release_stake(c.creator_id, c.stake_gems);
    update public.challenges set status = 'expired' where id = c.id;
  end loop;
end $$;

-- Solo per il test: se rimani sotto 100 Gemme puoi ricaricarne 500 (Gemme finte).
create or replace function public.claim_test_gems()
returns int language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_bal int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select balance_gems into v_bal from public.wallets where user_id = v_uid for update;
  if v_bal >= 100 then raise exception 'balance_not_low'; end if;
  update public.wallets set balance_gems = balance_gems + 500, updated_at = now() where user_id = v_uid;
  insert into public.transactions (user_id, type, amount_gems, balance_before, balance_after)
    values (v_uid, 'test_grant', 500, v_bal, v_bal + 500);
  return v_bal + 500;
end $$;

-- ---------- SOLO SERVER (Edge Function con service role) ----------
-- winner NULL = pareggio/annullata: restituisce le puntate, nessuna fee.

create or replace function public.finish_match(p_match uuid, p_winner uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.matches; v_loser uuid; v_bal int;
begin
  select * into m from public.matches where id = p_match for update;
  if not found then raise exception 'match_not_found'; end if;
  if m.status <> 'in_progress' then return; end if;   -- idempotente

  perform 1 from public.wallets
    where user_id in (m.player1_id, m.player2_id) order by user_id for update;

  if p_winner is null then
    perform public._release_stake(m.player1_id, m.stake_gems, m.id);
    perform public._release_stake(m.player2_id, m.stake_gems, m.id);
    update public.matches set status = 'finished', winner_id = null, finished_at = now() where id = m.id;
    return;
  end if;

  if p_winner not in (m.player1_id, m.player2_id) then raise exception 'invalid_winner'; end if;
  v_loser := case when p_winner = m.player1_id then m.player2_id else m.player1_id end;

  select balance_gems into v_bal from public.wallets where user_id = p_winner;
  update public.wallets
    set hold_gems = hold_gems - m.stake_gems, balance_gems = balance_gems + m.prize_gems, updated_at = now()
    where user_id = p_winner;
  insert into public.transactions (user_id, match_id, type, amount_gems, balance_before, balance_after)
    values (p_winner, m.id, 'win', m.prize_gems, v_bal, v_bal + m.prize_gems);

  update public.wallets
    set hold_gems = hold_gems - m.stake_gems, updated_at = now()
    where user_id = v_loser;

  insert into public.platform_fees (match_id, fee_gems) values (m.id, m.fee_gems);

  -- ELO +15/-15 e XP (livello = 1 + xp/100)
  update public.users set elo_global = elo_global + 15, xp = xp + 10, level = 1 + (xp + 10) / 100
    where id = p_winner;
  update public.users set elo_global = greatest(100, elo_global - 15), xp = xp + 3, level = 1 + (xp + 3) / 100
    where id = v_loser;

  update public.matches set status = 'finished', winner_id = p_winner, finished_at = now() where id = m.id;
end $$;

-- ---------- permessi ----------

revoke all on function public.initial_game_data(text) from public, anon, authenticated;
revoke all on function public._release_stake(uuid, int, uuid) from public, anon, authenticated;
revoke all on function public.finish_match(uuid, uuid) from public, anon, authenticated;
grant execute on function public.finish_match(uuid, uuid) to service_role;

revoke all on function public.create_challenge(uuid, int) from public, anon;
revoke all on function public.cancel_challenge(uuid) from public, anon;
revoke all on function public.accept_challenge(uuid) from public, anon;
revoke all on function public.expire_stale_challenges() from public, anon;
revoke all on function public.claim_test_gems() from public, anon;
grant execute on function public.create_challenge(uuid, int) to authenticated;
grant execute on function public.cancel_challenge(uuid) to authenticated;
grant execute on function public.accept_challenge(uuid) to authenticated;
grant execute on function public.expire_stale_challenges() to authenticated;
grant execute on function public.claim_test_gems() to authenticated;

-- ---------- Realtime per l'app ----------
alter publication supabase_realtime add table public.matches;
alter publication supabase_realtime add table public.wallets;
alter publication supabase_realtime add table public.users;

-- 3) Funzioni giochi (include Forza 4 e Tris)
-- DuelApp - Scacchi via Lichess (passo 5). Esegui in SQL Editor DOPO functions.sql.
-- File CUMULATIVO: contiene tutti i giochi, quindi basta eseguire questo
-- (al posto di functions_forza4.sql e functions_tris.sql).

create or replace function public.initial_game_data(p_slug text)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare v_board text;
begin
  if p_slug = 'dama' then
    select string_agg(
      case when (r + c) % 2 = 1
        then case when r <= 2 then 'b' when r >= 5 then 'w' else '.' end
        else '.' end, '' order by r, c)
    into v_board
    from generate_series(0, 7) r, generate_series(0, 7) c;
    return jsonb_build_object('board', v_board, 'turn', 'w', 'moves', 0,
      'last_move_at', (extract(epoch from now()) * 1000)::bigint, 'last_move', null);
  elsif p_slug = 'forza4' then
    return jsonb_build_object('board', repeat('.', 42), 'turn', 'r', 'moves', 0,
      'last_move_at', (extract(epoch from now()) * 1000)::bigint, 'last_move', null);
  elsif p_slug = 'tris_pro' then
    return jsonb_build_object('board', '.........', 'turn', 'x', 'moves', 0,
      'queue_x', '[]'::jsonb, 'queue_o', '[]'::jsonb,
      'last_move_at', (extract(epoch from now()) * 1000)::bigint, 'last_move', null);
  elsif p_slug = 'scacchi' then
    -- la partita vera gira su Lichess; qui salviamo solo id e link (player1 = bianco)
    return jsonb_build_object('lichess_id', null, 'url_white', null, 'url_black', null,
      'moves', 0, 'last_move_at', (extract(epoch from now()) * 1000)::bigint);
  end if;
  return '{}'::jsonb;
end $$;

-- 4) Manutenzione e timeout
-- DuelApp - chiusura automatica partite ferme (passo 6). Esegui DOPO functions_scacchi.sql.
--
-- close_stale_matches(): se in una partita (Dama, Forza 4, Tris Pro) chi deve muovere
-- non lo fa da piu' di p_minutes minuti, perde l'avversario-inattivo e il vincitore prende il premio.
-- Gli Scacchi sono esclusi: il risultato lo decide Lichess ed e' letto da 'scacchi-lichess' (sync).

create or replace function public.close_stale_matches(p_minutes int default 10)
returns int language plpgsql security definer set search_path = '' as $$
declare
  r record;
  v_now_ms bigint := (extract(epoch from now()) * 1000)::bigint;
  v_closed int := 0;
begin
  for r in
    select m.id, m.player1_id, m.player2_id, m.game_data
    from public.matches m
    join public.games g on g.id = m.game_id
    where m.status = 'in_progress'
      and g.slug in ('dama', 'forza4', 'tris_pro')
      and (m.game_data ->> 'last_move_at')::bigint < v_now_ms - p_minutes::bigint * 60000
  loop
    -- w / r / x = player1; b / y / o = player2. Chi deve muovere e' fermo e perde.
    if (r.game_data ->> 'turn') in ('w', 'r', 'x') then
      perform public.finish_match(r.id, r.player2_id);
    else
      perform public.finish_match(r.id, r.player1_id);
    end if;
    v_closed := v_closed + 1;
  end loop;
  return v_closed;
end $$;

revoke all on function public.close_stale_matches(int) from public, anon, authenticated;
grant execute on function public.close_stale_matches(int) to service_role;

-- Pianificazione ogni minuto. Prima abilita l'estensione: Database > Extensions > pg_cron.
-- Poi esegui queste due righe (tolgi i commenti):
-- select cron.schedule('duelapp-close-stale-matches', '* * * * *', $$select public.close_stale_matches(10)$$);
-- select cron.schedule('duelapp-expire-challenges',   '* * * * *', $$select public.expire_stale_challenges()$$);

-- 5) Profilo, avatar, statistiche e username
-- DuelApp - profilo ricco (passo 7). Esegui DOPO functions_maintenance.sql.
-- Aggiunge: avatar, statistiche per gioco (ELO, V/S/P, serie), cambio nick, controllo nick libero.
-- Sostituisce finish_match perche' ora aggiorna anche le statistiche.

-- ---------- avatar e nick ----------
alter table public.users add column if not exists avatar text not null default '🦊';
alter table public.users add column if not exists avatar_color text not null default 'purple';
create unique index if not exists users_username_lower_idx on public.users (lower(username));
alter table public.users drop constraint if exists username_format;
alter table public.users add constraint username_format check (username ~ '^[A-Za-z0-9_]+$');

-- ---------- statistiche per gioco ----------
create table if not exists public.user_game_stats (
  user_id uuid not null references public.users(id) on delete cascade,
  game_id uuid not null references public.games(id),
  elo int not null default 1000,
  played int not null default 0,
  wins int not null default 0,
  losses int not null default 0,
  draws int not null default 0,
  streak int not null default 0,        -- vittorie consecutive in corso
  best_streak int not null default 0,
  primary key (user_id, game_id)
);
alter table public.user_game_stats enable row level security;
drop policy if exists "stats_select_all" on public.user_game_stats;
create policy "stats_select_all" on public.user_game_stats
  for select to authenticated using (true);   -- statistiche pubbliche (utili per i profili altrui)

do $$ begin
  alter publication supabase_realtime add table public.user_game_stats;
exception when duplicate_object then null; end $$;

create or replace function public._record_result(p_user uuid, p_game uuid, p_result text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into public.user_game_stats (user_id, game_id) values (p_user, p_game)
    on conflict do nothing;
  if p_result = 'win' then
    update public.user_game_stats
      set played = played + 1, wins = wins + 1, elo = elo + 15,
          streak = streak + 1, best_streak = greatest(best_streak, streak + 1)
      where user_id = p_user and game_id = p_game;
  elsif p_result = 'loss' then
    update public.user_game_stats
      set played = played + 1, losses = losses + 1, elo = greatest(100, elo - 15), streak = 0
      where user_id = p_user and game_id = p_game;
  else
    update public.user_game_stats
      set played = played + 1, draws = draws + 1, streak = 0
      where user_id = p_user and game_id = p_game;
  end if;
end $$;

-- ---------- finish_match aggiornata (stessa logica + statistiche) ----------
create or replace function public.finish_match(p_match uuid, p_winner uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.matches; v_loser uuid; v_bal int;
begin
  select * into m from public.matches where id = p_match for update;
  if not found then raise exception 'match_not_found'; end if;
  if m.status <> 'in_progress' then return; end if;   -- idempotente

  perform 1 from public.wallets
    where user_id in (m.player1_id, m.player2_id) order by user_id for update;

  if p_winner is null then
    perform public._release_stake(m.player1_id, m.stake_gems, m.id);
    perform public._release_stake(m.player2_id, m.stake_gems, m.id);
    perform public._record_result(m.player1_id, m.game_id, 'draw');
    perform public._record_result(m.player2_id, m.game_id, 'draw');
    update public.matches set status = 'finished', winner_id = null, finished_at = now() where id = m.id;
    return;
  end if;

  if p_winner not in (m.player1_id, m.player2_id) then raise exception 'invalid_winner'; end if;
  v_loser := case when p_winner = m.player1_id then m.player2_id else m.player1_id end;

  select balance_gems into v_bal from public.wallets where user_id = p_winner;
  update public.wallets
    set hold_gems = hold_gems - m.stake_gems, balance_gems = balance_gems + m.prize_gems, updated_at = now()
    where user_id = p_winner;
  insert into public.transactions (user_id, match_id, type, amount_gems, balance_before, balance_after)
    values (p_winner, m.id, 'win', m.prize_gems, v_bal, v_bal + m.prize_gems);

  update public.wallets
    set hold_gems = hold_gems - m.stake_gems, updated_at = now()
    where user_id = v_loser;

  insert into public.platform_fees (match_id, fee_gems) values (m.id, m.fee_gems);

  -- ELO globale +15/-15, XP (livello = 1 + xp/100)
  update public.users set elo_global = elo_global + 15, xp = xp + 10, level = 1 + (xp + 10) / 100
    where id = p_winner;
  update public.users set elo_global = greatest(100, elo_global - 15), xp = xp + 3, level = 1 + (xp + 3) / 100
    where id = v_loser;

  perform public._record_result(p_winner, m.game_id, 'win');
  perform public._record_result(v_loser, m.game_id, 'loss');

  update public.matches set status = 'finished', winner_id = p_winner, finished_at = now() where id = m.id;
end $$;

-- ---------- API client ----------

-- true se il nick e' libero (richiamabile anche prima della registrazione)
create or replace function public.check_username(p_username text)
returns boolean language sql stable security definer set search_path = '' as $$
  select not exists (select 1 from public.users where lower(username) = lower(trim(p_username)));
$$;

create or replace function public.update_profile(p_username text, p_avatar text, p_color text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_name text := trim(p_username);
  v_avatars text[] := array['🦊','🐼','🐯','🦁','🐸','🐙','🦉','🐲','🚀','👾','🎮','👑','🔥','⚡','🧠','🎯'];
  v_colors text[] := array['purple','blue','teal','green','orange','red','pink','grey'];
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if v_name !~ '^[A-Za-z0-9_]{3,20}$' then raise exception 'username_invalid'; end if;
  if not (p_avatar = any (v_avatars)) then raise exception 'avatar_invalid'; end if;
  if not (p_color = any (v_colors)) then raise exception 'color_invalid'; end if;
  begin
    update public.users set username = v_name, avatar = p_avatar, avatar_color = p_color where id = v_uid;
  exception when unique_violation then
    raise exception 'username_taken';
  end;
end $$;

-- ---------- permessi ----------
revoke all on function public._record_result(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.finish_match(uuid, uuid) from public, anon, authenticated;
grant execute on function public.finish_match(uuid, uuid) to service_role;

revoke all on function public.check_username(text) from public;
grant execute on function public.check_username(text) to anon, authenticated;
revoke all on function public.update_profile(text, text, text) from public, anon;
grant execute on function public.update_profile(text, text, text) to authenticated;
