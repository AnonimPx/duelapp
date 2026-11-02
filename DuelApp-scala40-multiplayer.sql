-- DuelApp — Scala 40 multiplayer 2/3/4 giocatori
-- Il creatore sceglie una puntata unica; ogni partecipante versa esattamente quella cifra.
-- Eseguire dopo lo schema e le funzioni base.

insert into public.games (slug, name, type, is_active)
values ('scala40', 'Scala 40', 'internal', true)
on conflict (slug) do update set name = excluded.name, type = excluded.type, is_active = true;

alter table public.matches add column if not exists player_ids uuid[];
alter table public.matches add column if not exists max_players int not null default 2;

update public.matches
set player_ids = array[player1_id, player2_id]
where player_ids is null;

-- Le partite nuove conservano automaticamente i primi due partecipanti.
create or replace function public.sync_match_players()
returns trigger language plpgsql as $$
begin
  if new.player_ids is null or cardinality(new.player_ids) = 0 then
    new.player_ids := array[new.player1_id, new.player2_id];
  end if;
  if new.max_players is null or new.max_players < 2 then
    new.max_players := case when exists (
      select 1 from public.games g where g.id = new.game_id and g.slug = 'scala40'
    ) then 4 else 2 end;
  end if;
  return new;
end;
$$;
drop trigger if exists matches_sync_players on public.matches;
create trigger matches_sync_players before insert or update on public.matches
for each row execute function public.sync_match_players();

-- La vecchia verifica "piatto da 2" non vale per Scala 40.
do $$
declare c record;
begin
  for c in select conname from pg_constraint
    where conrelid = 'public.matches'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%prize_gems%fee_gems%stake_gems%'
  loop execute format('alter table public.matches drop constraint if exists %I', c.conname); end loop;
end $$;

drop policy if exists "matches_select_participant" on public.matches;
create policy "matches_select_participant" on public.matches
for select to authenticated
using (
  auth.uid() = any(coalesce(player_ids, array[player1_id, player2_id]))
  or (
    status = 'in_progress'
    and max_players > cardinality(coalesce(player_ids, array[player1_id, player2_id]))
    and exists (select 1 from public.games g where g.id = game_id and g.slug = 'scala40')
  )
);

create or replace function public.join_scala40(p_match uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  m public.matches;
  v_bal int;
  v_players uuid[];
  v_count int;
  v_fee int;
  v_prize int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select m0.* into m from public.matches m0
    join public.games g on g.id = m0.game_id
    where m0.id = p_match and g.slug = 'scala40' for update;
  if not found then raise exception 'scala40_match_not_found'; end if;
  v_players := coalesce(m.player_ids, array[m.player1_id, m.player2_id]);
  if m.status <> 'in_progress' then raise exception 'match_not_available'; end if;
  if v_uid = any(v_players) then return p_match; end if;
  if cardinality(v_players) >= least(greatest(m.max_players, 2), 4) then raise exception 'table_full'; end if;

  select balance_gems into v_bal from public.wallets where user_id = v_uid for update;
  if v_bal < m.stake_gems then raise exception 'insufficient_funds'; end if;
  update public.wallets set balance_gems = balance_gems - m.stake_gems, hold_gems = hold_gems + m.stake_gems, updated_at = now() where user_id = v_uid;
  insert into public.transactions(user_id, match_id, type, amount_gems, balance_before, balance_after)
    values(v_uid, p_match, 'stake_hold', -m.stake_gems, v_bal, v_bal - m.stake_gems);

  v_players := array_append(v_players, v_uid);
  v_count := cardinality(v_players);
  v_fee := floor((m.stake_gems * v_count * 20) / 100.0);
  v_prize := m.stake_gems * v_count - v_fee;
  update public.matches
    set player_ids = v_players,
        fee_gems = v_fee,
        prize_gems = v_prize,
        game_data = jsonb_set(jsonb_set(coalesce(game_data, '{}'::jsonb), '{player_ids}', to_jsonb(v_players)), '{player_count}', to_jsonb(v_count))
    where id = p_match;
  return p_match;
end $$;

grant execute on function public.join_scala40(uuid) to authenticated;

create or replace function public.finish_scala40(p_match uuid, p_winner uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  m public.matches;
  p uuid;
  v_bal int;
  v_players uuid[];
begin
  select * into m from public.matches where id = p_match for update;
  if not found or m.status <> 'in_progress' then return; end if;
  v_players := coalesce(m.player_ids, array[m.player1_id, m.player2_id]);
  if not (p_winner = any(v_players)) then raise exception 'invalid_winner'; end if;
  select balance_gems into v_bal from public.wallets where user_id = p_winner for update;
  update public.wallets set hold_gems = hold_gems - m.stake_gems, balance_gems = balance_gems + m.prize_gems, updated_at = now() where user_id = p_winner;
  insert into public.transactions(user_id, match_id, type, amount_gems, balance_before, balance_after)
    values(p_winner, p_match, 'win', m.prize_gems, v_bal, v_bal + m.prize_gems);
  foreach p in array v_players loop
    if p <> p_winner then
      update public.wallets set hold_gems = hold_gems - m.stake_gems, updated_at = now() where user_id = p;
    end if;
  end loop;
  insert into public.platform_fees(match_id, fee_gems) values(p_match, m.fee_gems) on conflict (match_id) do nothing;
  update public.matches set status = 'finished', winner_id = p_winner, finished_at = now() where id = p_match;
end $$;

grant execute on function public.finish_scala40(uuid, uuid) to service_role;
