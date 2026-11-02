import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';

class Scala40Screen extends StatelessWidget {
  final String matchId;
  const Scala40Screen({super.key, required this.matchId});
  @override
  Widget build(BuildContext context) => GameShell(
        matchId: matchId,
        title: 'Scala 40',
        fn: 'scala40-move',
        isMyTurn: (gd, isP1) {
          final players = (gd['players'] as List?) ?? const [];
          final uid = (gd['current_user_id'] ?? (isP1 ? 'p1' : 'p2')).toString();
          final index = players.indexWhere((p) => '${(p as Map)['id']}' == uid);
          return index >= 0 ? gd['turn'] == index : gd['turn'] == (isP1 ? 0 : 1);
        },
        sideP1: 'Giocatore 1',
        sideP2: 'Giocatore 2',
        colorP1: Pal.cyan,
        colorP2: Pal.pink,
        hint: 'Pesca una carta, forma combinazioni e poi scarta.',
        rules: 'Scala 40 si gioca in 2, 3 o 4. Chi crea il tavolo decide la puntata: tutti i partecipanti versano la stessa cifra. Ogni giocatore pesca e scarta una carta per turno. Per aprire bisogna calare combinazioni per almeno 40 punti. Il banco trattiene il 20% del totale e il vincitore riceve il resto.',
        boardBuilder: (_, ctx) => Scala40Board(ctx: ctx),
      );
}

class Scala40Board extends StatefulWidget {
  final MatchCtx ctx;
  const Scala40Board({super.key, required this.ctx});
  @override
  State<Scala40Board> createState() => _Scala40BoardState();
}

class _Scala40BoardState extends State<Scala40Board> {
  Map<String, dynamic>? get me {
    final ps = (widget.ctx.gd['players'] as List?) ?? const [];
    for (final p in ps) if ('${(p as Map)['id']}' == widget.ctx.uid) return Map<String, dynamic>.from(p);
    return ps.isNotEmpty ? Map<String, dynamic>.from(ps.first as Map) : null;
  }
  String _card(dynamic c) {
    final m = Map<String, dynamic>.from(c as Map);
    if (m['joker'] == true) return 'Jolly';
    const ranks = {1: 'A', 11: 'J', 12: 'Q', 13: 'K'};
    return '${ranks[m['rank']] ?? m['rank']}${m['suit']}';
  }
  @override
  Widget build(BuildContext context) {
    final p = me, hand = (p?['hand'] as List?) ?? const [];
    final players = (widget.ctx.gd['players'] as List?) ?? const [];
    final stock = (widget.ctx.gd['stock'] as List?) ?? const [];
    final discard = (widget.ctx.gd['discard'] as List?) ?? const [];
    return Column(children: [
      Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [for (var i = 0; i < players.length; i++) Chip(label: Text('G${i + 1} ${(players[i] as Map)['hand']?.length ?? 0} carte'))]),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        FilledButton.tonalIcon(onPressed: widget.ctx.myTurn && !widget.ctx.busy ? () => widget.ctx.call('draw') : null, icon: const Icon(Icons.layers), label: Text('Pesca (${stock.length})')),
        const SizedBox(width: 10),
        FilledButton.tonalIcon(onPressed: widget.ctx.myTurn && !widget.ctx.busy && discard.isNotEmpty ? () => widget.ctx.call('draw', {'from_discard': true}) : null, icon: const Icon(Icons.undo), label: Text('Scarti: ${discard.isEmpty ? '—' : _card(discard.last)}')),
      ]),
      const SizedBox(height: 14),
      Expanded(child: SingleChildScrollView(child: Wrap(spacing: 7, runSpacing: 7, alignment: WrapAlignment.center, children: [for (final card in hand) Card(color: Pal.violet.withValues(alpha: 0.35), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12), child: Text(_card(card), style: const TextStyle(fontWeight: FontWeight.w800))))]))),
      if (widget.ctx.myTurn && !widget.ctx.busy) const Text('Seleziona una carta per scartarla nella prossima versione del tavolo.', style: TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
    ]);
  }
}
