import 'package:flutter/material.dart';
import '../audio.dart';
import '../theme.dart';
import '../widgets.dart';

class DominoScreen extends StatelessWidget {
  final String matchId;
  const DominoScreen({super.key, required this.matchId});
  @override
  Widget build(BuildContext context) => GameShell(
        matchId: matchId,
        title: 'Domino',
        fn: 'domino-move',
        isMyTurn: (gd, isP1) => gd['turn'] == (isP1 ? 'w' : 'b'),
        sideP1: 'Giocatore 1',
        sideP2: 'Giocatore 2',
        colorP1: Pal.cyan,
        colorP2: Pal.gold,
        rules: 'Domino classico per due giocatori. Gioca una tessera collegando lo stesso numero a sinistra o a destra della catena. Se non puoi giocare, pesca; se non ci sono tessere disponibili passa. Vince chi finisce le tessere o chi ha meno punti quando il gioco è bloccato.',
        hint: 'Tocca una tessera e scegli Sinistra o Destra.',
        boardBuilder: (_, ctx) => DominoBoard(ctx: ctx),
      );
}

class DominoBoard extends StatefulWidget {
  final MatchCtx ctx;
  const DominoBoard({super.key, required this.ctx});
  @override
  State<DominoBoard> createState() => _DominoBoardState();
}

class _DominoBoardState extends State<DominoBoard> {
  int? selected;
  List<List<dynamic>> _tiles(String key) => List<List<dynamic>>.from((widget.ctx.gd[key] ?? const []) as List).map((t) => List<dynamic>.from(t)).toList();

  @override
  Widget build(BuildContext context) {
    final c = widget.ctx;
    final hand = _tiles(c.isP1 ? 'hand_w' : 'hand_b');
    final board = _tiles('board');
    final stock = _tiles('stock');
    return Column(children: [
      Text('Catena: ${board.length} tessere · Riserva: ${stock.length}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Expanded(child: Center(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        if (board.isEmpty) const Text('Gioca la prima tessera', style: TextStyle(color: Colors.white54)),
        for (final t in board) _tile(t, false),
      ])))),
      if (c.myTurn && !c.busy && selected != null && board.isNotEmpty)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FilledButton.tonal(onPressed: () => _play('left'), child: const Text('Sinistra')),
          const SizedBox(width: 10),
          FilledButton.tonal(onPressed: () => _play('right'), child: const Text('Destra')),
        ]),
      const SizedBox(height: 10),
      Text('La tua mano (${hand.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      SizedBox(height: 72, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: hand.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) => GestureDetector(onTap: c.myTurn && !c.busy ? () => setState(() => selected = selected == i ? null : i) : null, child: _tile(hand[i], selected == i)))),
      const SizedBox(height: 10),
      if (c.myTurn && !c.busy && stock.isNotEmpty) OutlinedButton.icon(onPressed: () => c.call('draw', {}), icon: const Icon(Icons.add), label: const Text('Pesca tessera')),
      const SizedBox(height: 6),
    ]);
  }

  Widget _tile(List<dynamic> t, bool active) => Container(
        width: 54,
        height: 64,
        decoration: BoxDecoration(color: active ? Pal.violet.withValues(alpha: 0.55) : const Color(0xFFEEE2C6), borderRadius: BorderRadius.circular(10), border: Border.all(color: active ? Pal.cyan : Colors.black38, width: active ? 3 : 1)),
        child: Column(children: [
          Expanded(child: Center(child: Text('${t[0]}', style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w900)))),
          Container(height: 1, color: Colors.black54),
          Expanded(child: Center(child: Text('${t[1]}', style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w900)))),
        ]),
      );

  void _play(String end) {
    if (selected == null) return;
    Sfx.i.play('move', haptic: true);
    widget.ctx.call('play', {'hand_index': selected, 'end': end});
    setState(() => selected = null);
  }
}
