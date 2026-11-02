// Edge Function: arbitro server-autoritativo della Dama.
// Deploy: supabase functions deploy dama-move
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { applyPath, describeMove, hasAnyMove, positionKey, type Side } from './dama.ts';

// Pareggio: 40 mosse per parte (80 semimosse) solo di dame senza prese, oppure stessa posizione 3 volte.
const MAX_QUIET_PLIES = 80;
const TIMEOUT_MS = 5 * 60 * 1000; // dopo 5 minuti senza mossa si puo' rivendicare la vittoria
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: 'unauthorized' }, 401);

    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { match_id, action, path } = await req.json();

    const { data: m } = await admin.from('matches').select('*').eq('id', match_id).maybeSingle();
    if (!m) return json({ error: 'match_not_found' }, 404);
    if (m.player1_id !== user.id && m.player2_id !== user.id) return json({ error: 'forbidden' }, 403);
    if (m.status !== 'in_progress') return json({ error: 'match_over' }, 409);

    const me: Side = user.id === m.player1_id ? 'w' : 'b';
    const opp: string = me === 'w' ? m.player2_id : m.player1_id;
    const gd = m.game_data;

    const finish = async (winner: string | null) => {
      const { error } = await admin.rpc('finish_match', { p_match: m.id, p_winner: winner });
      if (error) throw error;
    };

    if (action === 'resign') {
      await finish(opp);
      return json({ ok: true });
    }

    if (action === 'claim_timeout') {
      if (gd.turn === me) return json({ error: 'not_waiting_for_opponent' }, 400);
      if (Date.now() - Number(gd.last_move_at) < TIMEOUT_MS) return json({ error: 'timeout_not_reached' }, 400);
      await finish(user.id);
      return json({ ok: true });
    }

    if (action !== 'move') return json({ error: 'unknown_action' }, 400);
    if (gd.turn !== me) return json({ error: 'not_your_turn' }, 400);
    if (!Array.isArray(path)) return json({ error: 'bad_path' }, 400);

    const res = applyPath(gd.board, me, path.map(Number));
    if ('error' in res) return json({ error: res.error }, 400);

    const next: Side = me === 'w' ? 'b' : 'w';

    // Contatori per i pareggi: una presa o una mossa di pedina e' irreversibile e azzera tutto.
    const mv = describeMove(gd.board, path.map(Number));
    const irreversible = mv.capture || !mv.kingMove;
    const key = positionKey(res.board, next);
    const quiet: number = irreversible ? 0 : Number(gd.quiet ?? 0) + 1;
    const positions: Record<string, number> = irreversible ? {} : { ...(gd.positions ?? {}) };
    positions[key] = (positions[key] ?? 0) + 1;
    const isDraw = quiet >= MAX_QUIET_PLIES || positions[key] >= 3;

    const newData = {
      board: res.board,
      turn: next,
      moves: gd.moves + 1,
      last_move_at: Date.now(),
      last_move: path,
      quiet,
      positions,
    };

    // concorrenza ottimistica: aggiorna solo se nessun'altra mossa e' arrivata nel frattempo
    const { data: upd, error: updErr } = await admin
      .from('matches')
      .update({ game_data: newData })
      .eq('id', m.id)
      .eq('status', 'in_progress')
      .eq('game_data->>moves', String(gd.moves))
      .select('id');
    if (updErr) throw updErr;
    if (!upd || upd.length === 0) return json({ error: 'conflict_retry' }, 409);

    // chi resta senza mosse o senza pezzi perde; altrimenti controllo i pareggi
    if (!hasAnyMove(res.board, next)) await finish(user.id);
    else if (isDraw) await finish(null);

    return json({ ok: true });
  } catch (e) {
    console.error(e);
    return json({ error: 'server_error' }, 500);
  }
});
