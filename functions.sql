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
