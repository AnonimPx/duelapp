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
  ('othello', 'Othello', 'internal'),
  ('mulino', 'Mulino', 'internal'),
  ('domino', 'Domino', 'internal'),
  ('scopa', 'Scopa', 'internal'),
  ('backgammon', 'Backgammon', 'internal'),
  ('scala40', 'Scala 40', 'internal'),
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
