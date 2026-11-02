import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../audio.dart';
import '../avatars.dart';
import '../connection.dart';
import '../supa.dart';
import '../theme.dart';
import '../widgets.dart';
import 'edit_profile_screen.dart';

class ProfileTab extends StatefulWidget {
  final void Function(String) onOpenMatch;
  const ProfileTab({super.key, required this.onOpenMatch});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, Map<String, dynamic>> _games = {}; // game_id -> {name, slug}
  late final String _uid = supa.auth.currentUser!.id;
  late final Stream<Rows> _user = resilient(() => supa.from('users').stream(primaryKey: ['id']).eq('id', _uid));
  late final Stream<Rows> _stats =
      resilient(() => supa.from('user_game_stats').stream(primaryKey: ['user_id', 'game_id']).eq('user_id', _uid));
  late final Stream<Rows> _wallet = resilient(() => supa.from('wallets').stream(primaryKey: ['user_id']).eq('user_id', _uid));
  late final Stream<Rows> _matches = resilient(() => supa.from('matches').stream(primaryKey: ['id']));

  @override
  void initState() {
    super.initState();
    supa.from('games').select('id,name,slug').then((rows) {
      if (mounted) setState(() => _games = {for (final g in rows) g['id'] as String: Map<String, dynamic>.from(g)});
    }).catchError((_) {});
  }

  Future<void> _topUp() async {
    try {
      await supa.rpc('claim_test_gems');
      Sfx.i.play('coin', haptic: true);
    } on PostgrestException catch (e) {
      if (mounted) toast(context, errText(e.message), error: true);
    }
  }

  void _edit(Map<String, dynamic> u) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditProfileScreen(
        username: u['username'] as String,
        avatar: u['avatar'] as String,
        color: u['avatar_color'] as String,
      ),
    ));
  }

  Widget _header(Map<String, dynamic> u) {
    final level = u['level'] as int;
    final xp = u['xp'] as int;
    final progress = (xp % 100) / 100;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Pal.violet.withValues(alpha: 0.55), Pal.cyan.withValues(alpha: 0.18)],
        ),
        border: Border.all(color: Pal.border),
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => _edit(u),
            child: Stack(children: [
              AvatarCircle(emoji: u['avatar'] as String, color: u['avatar_color'] as String, size: 78),
              const Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(radius: 13, backgroundColor: Colors.white, child: Icon(Icons.edit, size: 15, color: Colors.black87)),
              ),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${u['username']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Pal.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(levelTitle(level), style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(height: 4),
              Text('ELO globale ${u['elo_global']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Text('Livello $level', style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('${xp % 100}/100 XP', style: const TextStyle(color: Colors.white70)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 12,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Pal.gold),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
      );

  Widget _statsCard(Rows stats) {
    int sum(String k) => stats.fold(0, (a, s) => a + (s[k] as int));
    final played = sum('played');
    final wins = sum('wins');
    final best = stats.fold<int>(0, (a, s) => (s['best_streak'] as int) > a ? s['best_streak'] as int : a);
    final rate = played == 0 ? '—' : '${(wins * 100 / played).round()}%';
    final sorted = [...stats]..sort((a, b) => (b['played'] as int).compareTo(a['played'] as int));
    return GlassCard(
      margin: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Statistiche', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 14),
        Row(children: [
          _stat('Partite', '$played', Colors.white),
          _stat('Vittorie', '$wins', Pal.green),
          _stat('% vittorie', rate, Pal.cyan),
          _stat('Miglior serie', '$best', Pal.gold),
        ]),
        if (sorted.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 14), child: Text('Gioca la tua prima partita dalla Bacheca!', style: TextStyle(color: Colors.white60)))
        else ...[
          const Divider(height: 26, color: Pal.border),
          for (final s in sorted) _gameStat(s),
        ],
      ]),
    );
  }

  Widget _gameStat(Map<String, dynamic> s) {
    final g = _games[s['game_id']];
    final st = gameStyle(g?['slug'] as String?);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: st.color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
          child: Icon(st.icon, color: st.color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${g?['name'] ?? 'Gioco'}', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('V ${s['wins']} · S ${s['losses']} · P ${s['draws']} · serie ${s['streak']} (record ${s['best_streak']})',
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
        ),
        Text('${s['elo']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Pal.cyan)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListView(
        physics: const ClampingScrollPhysics(),
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.all(16),
        children: [
      Row(children: const [
        Expanded(child: Text('Il mio profilo', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
        MuteButton(),
      ]),
      const SizedBox(height: 8),
      StreamBuilder<Rows>(
        stream: _user,
        builder: (c, s) {
          final u = s.data?.firstOrNull;
          return u == null ? const SizedBox(height: 170, child: Center(child: CircularProgressIndicator())) : _header(u);
        },
      ),
      StreamBuilder<Rows>(
        stream: _wallet,
        builder: (c, s) {
          final w = s.data?.firstOrNull;
          final bal = (w?['balance_gems'] ?? 0) as num;
          return GlassCard(
            margin: const EdgeInsets.only(top: 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Wallet (Gemme di test)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 4),
                  Text('${w?['hold_gems'] ?? 0} in gioco', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  if (bal < 100)
                    TextButton(onPressed: _topUp, child: const Text('Ricarica 500 Gemme di test')),
                ]),
              ),
              GemChip(bal, big: true),
            ]),
          );
        },
      ),
      StreamBuilder<Rows>(
        stream: _stats,
        builder: (c, s) => _statsCard(s.data ?? <Map<String, dynamic>>[]),
      ),
      const SizedBox(height: 18),
      const Text('Le tue partite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      StreamBuilder<Rows>(
        stream: _matches,
        builder: (c, s) {
          final rows = [...(s.data ?? <Map<String, dynamic>>[])]
            ..sort((a, b) => '${b['started_at']}'.compareTo('${a['started_at']}'));
          if (rows.isEmpty) {
            return const Padding(padding: EdgeInsets.all(16), child: Text('Nessuna partita ancora.', style: TextStyle(color: Colors.white60)));
          }
          return Column(children: rows.take(15).map(_matchRow).toList());
        },
      ),
      const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => supa.auth.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Esci'),
          ),
        ],
      ),
    );
  }

  Widget _matchRow(Map<String, dynamic> m) {
    final live = m['status'] == 'in_progress';
    final g = _games[m['game_id']];
    final st = gameStyle(g?['slug'] as String?);
    String res;
    Color col;
    if (live) {
      res = 'In corso · tocca per riprendere';
      col = Pal.cyan;
    } else if (m['status'] == 'cancelled' || m['winner_id'] == null) {
      res = 'Pareggio';
      col = Pal.gold;
    } else if (m['winner_id'] == _uid) {
      res = 'Vinta +${m['prize_gems']} 💎';
      col = Pal.green;
    } else {
      res = 'Persa -${m['stake_gems']} 💎';
      col = Pal.red;
    }
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        onTap: live ? () => widget.onOpenMatch(m['id'] as String) : null,
        child: Row(children: [
          Icon(st.icon, color: st.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${g?['name'] ?? 'Partita'} · puntata ${m['stake_gems']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(res, style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
          if (live) const Icon(Icons.play_circle_fill, color: Pal.cyan),
        ]),
      ),
    );
  }
}
