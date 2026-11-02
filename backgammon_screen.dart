import 'package:flutter/material.dart';
import '../audio.dart';
import '../theme.dart';
import '../widgets.dart';

class BackgammonScreen extends StatelessWidget {
  final String matchId;
  const BackgammonScreen({super.key, required this.matchId});
  @override
  Widget build(BuildContext context) => GameShell(
        matchId: matchId,
        title: 'Backgammon',
        fn: 'backgammon-move',
        isMyTurn: (gd, isP1) => gd['turn'] == (isP1 ? 'w' : 'b'),
        sideP1: 'Bianche',
        sideP2: 'Nere',
        colorP1: Pal.cyan,
        colorP2: Pal.gold,
        rules: 'Backgammon classico per due giocatori. Lancia i dadi, seleziona una tua pedina e poi il dado da usare. Puoi mangiare una pedina isolata, rientrare dalla barra e portare fuori le pedine quando sono tutte nella casa.',
        hint: 'Lancia i dadi, tocca un punto e scegli il dado.',
        boardBuilder: (_, ctx) => BackgammonBoard(ctx: ctx),
      );
}

class BackgammonBoard extends StatefulWidget {
  final MatchCtx ctx;
  const BackgammonBoard({super.key, required this.ctx});
  @override
  State<BackgammonBoard> createState() => _BackgammonBoardState();
}

class _BackgammonBoardState extends State<BackgammonBoard> {
  int? selected;
  List<int> _board() => List<int>.from((widget.ctx.gd['board'] ?? List.filled(24, 0)) as List);
  List<int> _dice() => List<int>.from((widget.ctx.gd['dice'] ?? const []) as List);
  @override
  Widget build(BuildContext context) {
    final c = widget.ctx, board = _board(), dice = _dice();
    final isWhite = c.isP1;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Text('Barra: ${c.gd[isWhite ? 'bar_w' : 'bar_b'] ?? 0}', style: const TextStyle(color: Colors.white70)), Text('Fuori: ${c.gd[isWhite ? 'off_w' : 'off_b'] ?? 0}/15', style: const TextStyle(color: Colors.white70)), Text('Dadi: ${dice.isEmpty ? '—' : dice.join(' · ')}', style: const TextStyle(fontWeight: FontWeight.w800))]),
      const SizedBox(height: 12),
      Expanded(child: Column(children: [
        Expanded(child: Row(children: [for (var i = 12; i < 24; i++) Expanded(child: _point(i, board[i], c, isWhite))])),
        Container(height: 28, margin: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(color: Pal.violet.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('BAR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w800)))),
        Expanded(child: Row(children: [for (var i = 11; i >= 0; i--) Expanded(child: _point(i, board[i], c, isWhite))])),
      ])),
      const SizedBox(height: 10),
      if (c.myTurn && !c.busy && dice.isEmpty) FilledButton.icon(onPressed: () { Sfx.i.play('move', haptic: true); c.call('roll', {}); }, icon: const Icon(Icons.casino), label: const Text('Lancia i dadi')),
      if (c.myTurn && !c.busy && selected != null && dice.isNotEmpty) Wrap(spacing: 8, children: [for (final d in dice) FilledButton.tonal(onPressed: () { c.call('move', {'from': selected, 'die': d}); setState(() => selected = null); }, child: Text('Usa $d'))]),
      const SizedBox(height: 8),
    ]);
  }
  Widget _point(int i, int n, MatchCtx c, bool isWhite) {
    final mine = isWhite ? n > 0 : n < 0;
    final count = n.abs();
    return GestureDetector(onTap: c.myTurn && !c.busy ? () => setState(() => selected = mine ? i : selected) : null, child: Container(margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: selected == i ? Pal.cyan.withValues(alpha: 0.35) : (i.isEven ? const Color(0xFF603C32) : const Color(0xFFB8794A)), borderRadius: BorderRadius.circular(6)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('$i', style: const TextStyle(color: Colors.white54, fontSize: 11)), if (count > 0) Icon(Icons.circle, color: mine ? (isWhite ? Colors.white : Colors.black) : (isWhite ? Colors.black : Colors.white), size: 22), if (count > 1) Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])));
  }
}
