-- DuelApp: aggiunta Othello, Mulino e Domino al progetto già configurato.
-- Eseguire una volta in Supabase > SQL Editor quando riprenderemo l'aggiornamento database.

insert into public.games (slug, name, type) values
  ('othello', 'Othello', 'internal'),
  ('mulino', 'Mulino', 'internal'),
  ('domino', 'Domino', 'internal')
on conflict (slug) do update set name = excluded.name, type = excluded.type, is_active = true;

create or replace function public.initial_game_data(p_slug text)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare v_board text;
begin
  if p_slug = 'dama' then
    select string_agg(case when (r + c) % 2 = 1 then case when r <= 2 then 'b' when r >= 5 then 'w' else '.' end else '.' end, '' order by r, c)
    into v_board from generate_series(0, 7) r, generate_series(0, 7) c;
    return jsonb_build_object('board', v_board, 'turn', 'w', 'moves', 0, 'last_move_at', (extract(epoch from now()) * 1000)::bigint, 'last_move', null);
  elsif p_slug = 'forza4' then
    return jsonb_build_object('board', repeat('.', 42), 'turn', 'r', 'moves', 0, 'last_move_at', (extract(epoch from now()) * 1000)::bigint, 'last_move', null);
  elsif p_slug = 'tris_pro' then
    return jsonb_build_object('board', '.........', 'turn', 'x', 'moves', 0, 'last_move_at', (extract(epoch from now()) * 1000)::bigint, 'last_move', null);
  elsif p_slug = 'othello' then
    return jsonb_build_object('board', '...........................wb......bw...........................', 'turn', 'b', 'moves', 0, 'last_move_at', (extract(epoch from now()) * 1000)::bigint, 'last_move', null, 'pass_count', 0);
  elsif p_slug = 'mulino' then
    return jsonb_build_object('board', repeat('.', 24), 'turn', 'w', 'phase', 'placing', 'placed_w', 0, 'placed_b', 0, 'pending_remove', null, 'moves', 0, 'last_move_at', (extract(epoch from now()) * 1000)::bigint, 'last_move', null);
  elsif p_slug = 'domino' then
    return jsonb_build_object('board', '[]'::jsonb, 'hand_w', '[[0,0],[0,1],[0,2],[0,3],[0,4],[0,5],[0,6]]'::jsonb, 'hand_b', '[[1,1],[1,2],[1,3],[1,4],[1,5],[1,6],[2,2]]'::jsonb, 'stock', '[[2,3],[2,4],[2,5],[2,6],[3,3],[3,4],[3,5],[3,6],[4,4],[4,5],[4,6],[5,5],[5,6],[6,6]]'::jsonb, 'turn', 'w', 'passes', 0, 'moves', 0, 'last_move_at', (extract(epoch from now()) * 1000)::bigint, 'last_move', null);
  elsif p_slug = 'scacchi' then
    return jsonb_build_object('lichess_id', null, 'url_white', null, 'url_black', null, 'moves', 0, 'last_move_at', (extract(epoch from now()) * 1000)::bigint);
  end if;
  return '{}'::jsonb;
end $$;
