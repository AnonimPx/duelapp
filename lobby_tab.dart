import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../audio.dart';
import '../avatars.dart';
import '../connection.dart';
import '../supa.dart';
import '../theme.dart';
import '../widgets.dart';
import 'training_screen.dart';

class LobbyTab extends StatefulWidget {
  final void Function(String) onOpenMatch;
  const LobbyTab({super.key, required this.onOpenMatch});
  @override
  State<LobbyTab> createState() => _LobbyTabState();
}

class _LobbyTabState extends State<LobbyTab> {
  Map<String, Map<String, dynamic>> _games = {};
  List<Map<String, dynamic>> _scalaRooms = [];
  final Map<String, Future<Map<String, dynamic>>> _people = {};
  late final Stream<Rows> _challenges =
      resilient(() => supa.from('challenges').stream(primaryKey: ['id']).eq('status', 'open'));
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await supa.rpc('expire_stale_challenges');
    } catch (_) {}
    try {
      final g = await supa.from('games').select().eq('is_active', true);
      if (mounted) setState(() => _games = {for (final x in g) x['id'] as String: x});
      final scala = (g as List).where((x) => x['slug'] == 'scala40').toList();
      if (scala.isNotEmpty) {
        final rooms = await supa.from('matches').select().eq('game_id', scala.first['id']).eq('status', 'in_progress');
        if (mounted) setState(() => _scalaRooms = [for (final r in rooms) if (((r['player_ids'] as List?)?.length ?? 2) < (r['max_players'] ?? 4)) Map<String, dynamic>.from(r)]);
      }
    } catch (_) {
      if (mounted) toast(context, 'Non riesco a caricare i giochi: controlla la connessione.', error: true);
    }
  }

  Future<Map<String, dynamic>> _person(String id) => _people.putIfAbsent(id, () async {
        final r = await supa.from('users').select('username,avatar,avatar_color,elo_global').eq('id', id).maybeSingle();
        return r ?? <String, dynamic>{'username': '???', 'avatar': '🦊', 'avatar_color': 'purple', 'elo_global': 1000};
      });

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } on PostgrestException catch (e) {
      if (mounted) toast(context, errText(e.message), error: true);
    } catch (_) {
      if (mounted) toast(context, 'Connessione instabile, riprova.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final playable = _games.values
        .where((g) => const ['dama', 'forza4', 'tris_pro', 'othello', 'mulino', 'domino', 'scopa', 'backgammon', 'scala40', 'scacchi'].contains(g['slug']))
        .toList();
    if (playable.isEmpty) {
      toast(context, 'Nessun gioco disponibile, riprova tra poco.', error: true);
      _load();
      return;
    }
    Sfx.i.play('tap');
    final res = await showModalBottomSheet<(String, int)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF1A1E3C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => SafeArea(
        top: false,
        child: _NewChallengeSheet(games: playable),
      ),
    );
    if (res == null) return;
    await _run(() async {
      await supa.rpc('create_challenge', params: {'p_game_id': res.$1, 'p_stake': res.$2});
      Sfx.i.play('coin', haptic: true);
      if (mounted) toast(context, 'Sfida pubblicata! Attendi uno sfidante.');
    });
  }

  Future<void> _accept(String id) => _run(() async {
        final matchId = await supa.rpc('accept_challenge', params: {'p_id': id});
        widget.onOpenMatch('$matchId');
      });

  Future<void> _cancel(String id) => _run(() async {
        await supa.rpc('cancel_challenge', params: {'p_id': id});
        Sfx.i.play('tap');
      });

  @override
  Widget build(BuildContext context) {
    final uid = supa.auth.currentUser!.id;
    return Stack(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
          child: Row(children: [
            const Expanded(
              child: Text('⚔️ Bacheca sfide', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            ),
            const MuteButton(),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('Accetta una sfida o creane una: chi vince si prende il piatto.',
              style: TextStyle(color: Colors.white60)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainingScreen())),
            icon: const Icon(Icons.smart_toy_outlined),
            label: const Text('Allenamento vs CPU'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          ),
        ),
        if (_scalaRooms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tavoli Scala 40 aperti', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              for (final room in _scalaRooms) _scalaRoomCard(room, uid),
            ]),
          ),
        Expanded(
          child: StreamBuilder<Rows>(
            stream: _challenges,
            builder: (c, s) {
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final now = DateTime.now();
              final rows = s.data!
                  .where((r) => DateTime.parse(r['expires_at'] as String).isAfter(now))
                  .toList()
                ..sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
              if (rows.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: const [
                    SizedBox(height: 90),
                    Center(child: Text('🎲', style: TextStyle(fontSize: 64))),
                    SizedBox(height: 10),
                    Center(
                      child: Text('Nessuna sfida aperta.\nCreane una!',
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.white70)),
                    ),
                  ]),
                );
              }
              return RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
                  itemCount: rows.length,
                  itemBuilder: (_, i) => _challengeCard(rows[i], uid),
                ),
              );
            },
          ),
        ),
      ]),
      Positioned(
        right: 16,
        bottom: 16,
        child: FloatingActionButton.extended(
          onPressed: _busy ? null : _create,
          backgroundColor: Pal.violet,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuova sfida', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    ]);
  }

  Widget _scalaRoomCard(Map<String, dynamic> r, String uid) {
    final ids = List<String>.from((r['player_ids'] as List?) ?? [r['player1_id'], r['player2_id']]);
    final max = r['max_players'] ?? 4;
    final joined = ids.contains(uid);
    return Card(
      color: Pal.pink.withValues(alpha: 0.16),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.style_rounded, color: Pal.pink),
        title: Text('Scala 40 · ${ids.length}/$max giocatori'),
        subtitle: Text('Puntata tavolo 💎 ${r['stake_gems']} · uguale per tutti'),
        trailing: FilledButton(
          onPressed: _busy ? null : () => _run(() async {
            if (!joined) await supa.rpc('join_scala40', params: {'p_match': r['id']});
            widget.onOpenMatch(r['id'] as String);
          }),
          child: Text(joined ? 'Apri' : 'Entra'),
        ),
      ),
    );
  }

  Widget _challengeCard(Map<String, dynamic> r, String uid) {
    final mine = r['creator_id'] == uid;
    final game = _games[r['game_id']];
    final st = gameStyle(game?['slug'] as String?);
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      tint: mine ? Pal.violet.withValues(alpha: 0.16) : null,
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: st.color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
          child: Icon(st.icon, color: st.color, size: 30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${game?['name'] ?? 'Gioco'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            FutureBuilder<Map<String, dynamic>>(
              future: _person(r['creator_id'] as String),
              builder: (_, n) {
                final p = n.data;
                return Row(children: [
                  if (p != null) AvatarCircle(emoji: p['avatar'] as String, color: p['avatar_color'] as String, size: 20),
                  if (p != null) const SizedBox(width: 6),
                  Flexible(
                    child: Text(mine ? 'La tua sfida' : '${p?['username'] ?? '…'} · ELO ${p?['elo_global'] ?? '—'}',
                        overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ),
                ]);
              },
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          GemChip(r['stake_gems'] as num),
          const SizedBox(height: 8),
          mine
              ? TextButton(
                  onPressed: _busy ? null : () => _cancel(r['id'] as String),
                  style: TextButton.styleFrom(foregroundColor: Pal.red, visualDensity: VisualDensity.compact),
                  child: const Text('Annulla'),
                )
              : FilledButton(
                  onPressed: _busy ? null : () => _accept(r['id'] as String),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Accetta'),
                ),
        ]),
      ]),
    );
  }
}

class _NewChallengeSheet extends StatefulWidget {
  final List<Map<String, dynamic>> games;
  const _NewChallengeSheet({required this.games});
  @override
  State<_NewChallengeSheet> createState() => _NewChallengeSheetState();
}

class _NewChallengeSheetState extends State<_NewChallengeSheet> {
  late String _gameId = widget.games.first['id'] as String;
  int _stake = 100;
  final _ctrl = TextEditingController(text: '100');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        20,
        22,
        22 + MediaQuery.of(context).viewPadding.bottom + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Nuova sfida', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        const Text('Gioco', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final g in widget.games)
            ChoiceChip(
              avatar: Icon(gameStyle(g['slug'] as String?).icon, size: 18, color: gameStyle(g['slug'] as String?).color),
              label: Text('${g['name']}'),
              selected: _gameId == g['id'],
              onSelected: (_) {
                Sfx.i.play('tap');
                setState(() => _gameId = g['id'] as String);
              },
            ),
        ]),
        const SizedBox(height: 18),
        const Text('Puntata in Gemme (min 10)', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final v in const [10, 50, 100, 250, 500])
            ChoiceChip(
              label: Text('💎 $v'),
              selected: _stake == v,
              onSelected: (_) {
                Sfx.i.play('tap');
                setState(() {
                  _stake = v;
                  _ctrl.text = '$v';
                });
              },
            ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Oppure scrivi una cifra'),
          onChanged: (v) => setState(() => _stake = int.tryParse(v) ?? 0),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _stake >= 10 ? () => Navigator.pop(context, (_gameId, _stake)) : null,
            child: Text('Pubblica sfida · 💎 $_stake'),
          ),
        ),
      ]),
    );
  }
}
