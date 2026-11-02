import 'package:flutter/material.dart';
import '../audio.dart';
import '../theme.dart';
import '../widgets.dart';

class ScopaScreen extends StatelessWidget {
  final String matchId;
  const ScopaScreen({super.key, required this.matchId});
  @override
  Widget build(BuildContext context) => GameShell(
        matchId: matchId,
        title: 'Scopa',
        fn: 'scopa-move',
        isMyTurn: (gd, isP1) => gd['turn'] == (isP1 ? 'w' : 'b'),
        sideP1: 'Giocatore 1',
        sideP2: 'Giocatore 2',
        colorP1: Pal.cyan,
        colorP2: Pal.gold,
        rules: 'Scopa italiana per due giocatori. Gioca una carta per prendere una carta dello stesso valore oppure più carte la cui somma dà il valore giocato. Se prendi tutte le carte sul tavolo fai scopa. Vince il punteggio più alto.',
        hint: 'Seleziona una carta, seleziona le carte da prendere e premi Gioca.',
        boardBuilder: (_, ctx) => ScopaBoard(ctx: ctx),
      );
}

class ScopaBoard extends StatefulWidget {
  final MatchCtx ctx;
  const ScopaBoard({super.key, required this.ctx});
  @override
  State<ScopaBoard> createState() => _ScopaBoardState();
}

class _ScopaBoardState extends State<ScopaBoard> {
  int? handSelected;
  final selectedTable = <int>{};
  List<List<dynamic>> _cards(String key) => List<List<dynamic>>.from((widget.ctx.gd[key] ?? const []) as List).map((c) => List<dynamic>.from(c)).toList();

  @override
  Widget build(BuildContext context) {
    final c = widget.ctx;
    final hand = _cards(c.isP1 ? 'hand_w' : 'hand_b');
    final table = _cards('table');
    return Column(children: [
      Text('Tavolo · ${table.length} carte · Mazzo ${_cards('stock').length}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Expanded(child: Center(child: Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 0; i < table.length; i++) GestureDetector(onTap: c.myTurn && handSelected != null ? () => setState(() => selectedTable.contains(i) ? selectedTable.remove(i) : selectedTable.add(i)) : null, child: _card(table[i], selectedTable.contains(i), small: true))]))),
      if (c.myTurn && !c.busy && handSelected != null) FilledButton.icon(onPressed: _play, icon: const Icon(Icons.casino_outlined), label: const Text('Gioca carta')),
      const SizedBox(height: 8),
      Text('La tua mano (${hand.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      SizedBox(
        height: 82,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: hand.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => GestureDetector(
            onTap: c.myTurn && !c.busy
                ? () => setState(() {
                      handSelected = i;
                      selectedTable.clear();
                    })
                : null,
            child: _card(hand[i], handSelected == i),
          ),
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _card(List<dynamic> card, bool selected, {bool small = false}) {
    final suits = ['♦', '♣', '♥', '♠'];
    final colors = [Colors.red, Colors.black87, Colors.red, Colors.black87];
    final suit = (card[1] as num).toInt();
    return Container(width: small ? 52 : 60, height: small ? 70 : 78, padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: const Color(0xFFF3E8CF), borderRadius: BorderRadius.circular(9), border: Border.all(color: selected ? Pal.cyan : Colors.black38, width: selected ? 3 : 1)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${card[0]}', style: TextStyle(color: colors[suit], fontSize: 22, fontWeight: FontWeight.w900)), Text(suits[suit], style: TextStyle(color: colors[suit], fontSize: 16))]));
  }

  void _play() {
    if (handSelected == null) return;
    Sfx.i.play('move', haptic: true);
    widget.ctx.call('play', {'hand_index': handSelected, 'captures': selectedTable.toList()});
    setState(() { handSelected = null; selectedTable.clear(); });
  }
}
