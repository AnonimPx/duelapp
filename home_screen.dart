import 'dart:async';
import 'package:flutter/material.dart';
import '../audio.dart';
import '../connection.dart';
import '../supa.dart';
import '../widgets.dart';
import 'dama_screen.dart';
import 'forza4_screen.dart';
import 'leaderboard_tab.dart';
import 'lobby_tab.dart';
import 'othello_screen.dart';
import 'mulino_screen.dart';
import 'domino_screen.dart';
import 'scopa_screen.dart';
import 'backgammon_screen.dart';
import 'scala40_screen.dart';
import 'profile_tab.dart';
import 'scacchi_screen.dart';
import 'tris_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final _seen = <String>{}; // partite già gestite per l'apertura automatica
  final _active = <String>{}; // schermate partita attualmente aperte
  bool _first = true;
  StreamSubscription<Rows>? _sub;

  @override
  void initState() {
    super.initState();
    // Quando qualcuno accetta la mia sfida, la partita compare qui (RLS: solo le mie) e si apre da sola.
    _sub = resilient(() => supa.from('matches').stream(primaryKey: ['id'])).listen((rows) {
      for (final r in rows) {
        if (r['status'] != 'in_progress') continue;
        final id = r['id'] as String;
        if (_first) {
          _seen.add(id);
        } else if (_seen.add(id) && mounted) {
          openMatch(id);
        }
      }
      _first = false;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> openMatch(String id) async {
    _seen.add(id);
    if (!_active.add(id)) return;
    try {
      final r = await supa.from('matches').select('games(slug)').eq('id', id).single();
      final slug = (r['games'] as Map)['slug'];
      if (!mounted) return;
      Sfx.i.play('start', haptic: true);
      final Widget screen = switch (slug) {
        'forza4' => Forza4Screen(matchId: id),
        'tris_pro' => TrisScreen(matchId: id),
        'othello' => OthelloScreen(matchId: id),
        'mulino' => MulinoScreen(matchId: id),
        'domino' => DominoScreen(matchId: id),
        'scopa' => ScopaScreen(matchId: id),
        'backgammon' => BackgammonScreen(matchId: id),
        'scala40' => Scala40Screen(matchId: id),
        'scacchi' => ScacchiScreen(matchId: id),
        _ => DamaScreen(matchId: id),
      };
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    } catch (_) {
      if (mounted) toast(context, 'Impossibile aprire la partita, riprova.', error: true);
    } finally {
      _active.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      LobbyTab(onOpenMatch: openMatch),
      const LeaderboardTab(),
      ProfileTab(onOpenMatch: openMatch),
    ];
    return GScaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: tabs)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          Sfx.i.play('tap');
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.sports_esports_outlined), selectedIcon: Icon(Icons.sports_esports), label: 'Bacheca'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Classifica'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profilo'),
        ],
      ),
    );
  }
}
