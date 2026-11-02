import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';

class OthelloScreen extends StatelessWidget {
  final String matchId;
  const OthelloScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      matchId: matchId,
      title: 'Othello',
      fn: 'othello-move',
      isMyTurn: (gd, isP1) => gd['turn'] == (isP1 ? 'b' : 'w'),
      sideP1: 'Nero',
      sideP2: 'Bianco',
      colorP1: const Color(0xFF263238),
      colorP2: Colors.white,
      rules: 'Othello/Reversi per due giocatori. Metti una pedina in una casella vuota per chiudere una o più linee tra due tue pedine e ribaltare quelle avversarie. Se non hai mosse valide il turno passa automaticamente. Vince chi ha più pedine quando la board è piena o nessuno può più muovere.',
      hint: 'Tocca una casella evidenziata per ribaltare le pedine.',
      boardBuilder: (_, ctx) => OthelloBoard(ctx: ctx),
    );
  }
}

class OthelloBoard extends StatelessWidget {
  final MatchCtx ctx;
  const OthelloBoard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final b = ctx.board;
    final me = ctx.isP1 ? 'b' : 'w';
    final valid = ctx.myTurn && !ctx.busy ? _validMoves(b, me) : <int>{};
    final black = b.split('').where((p) => p == 'b').length;
    final white = b.split('').where((p) => p == 'w').length;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _score('Nero', black, Colors.white),
        const SizedBox(width: 24),
        _score('Bianco', white, Colors.white70),
      ]),
      const SizedBox(height: 10),
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: const Color(0xFF126B4D), borderRadius: BorderRadius.circular(18), border: Border.all(color: Pal.gold, width: 2)),
              child: GridView.count(
                crossAxisCount: 8,
                physics: const NeverScrollableScrollPhysics(),
                children: [for (var i = 0; i < 64; i++) _cell(i, b[i], valid.contains(i))],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(ctx.myTurn ? 'Il tuo turno' : 'Turno avversario', style: const TextStyle(color: Colors.white60, fontSize: 12)),
    ]);
  }

  Widget _score(String label, int value, Color color) => Row(children: [
        Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, color: label == 'Nero' ? Colors.black : Colors.white, border: Border.all(color: Colors.white54))),
        const SizedBox(width: 5),
        Text('$label $value', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ]);

  Widget _cell(int i, String p, bool canTap) => GestureDetector(
        onTap: canTap ? () => ctx.call('move', {'cell': i}) : null,
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(color: const Color(0xFF1A8A61), border: Border.all(color: Colors.white24)),
          child: Stack(alignment: Alignment.center, children: [
            if (canTap) Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Pal.gold)),
            if (p != '.') Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p == 'b' ? const Color(0xFF172027) : Colors.white, border: Border.all(color: p == 'b' ? Colors.white54 : Colors.black54, width: 1.5), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(1, 2))]),
            ),
          ]),
        ),
      );

  Set<int> _validMoves(String board, String me) {
    const dirs = [-1, 0, 1];
    final other = me == 'b' ? 'w' : 'b';
    final out = <int>{};
    for (var i = 0; i < 64; i++) {
      if (board[i] != '.') continue;
      final r = i ~/ 8, c = i % 8;
      for (final dr in dirs) {
        for (final dc in dirs) {
          if (dr == 0 && dc == 0) continue;
          var rr = r + dr, cc = c + dc, seen = false;
          while (rr >= 0 && rr < 8 && cc >= 0 && cc < 8 && board[rr * 8 + cc] == other) {
            seen = true;
            rr += dr;
            cc += dc;
          }
          if (seen && rr >= 0 && rr < 8 && cc >= 0 && cc < 8 && board[rr * 8 + cc] == me) out.add(i);
        }
      }
    }
    return out;
  }
}
