import 'package:flutter/material.dart';
import '../audio.dart';
import '../theme.dart';
import '../widgets.dart';

class MulinoScreen extends StatelessWidget {
  final String matchId;
  const MulinoScreen({super.key, required this.matchId});
  @override
  Widget build(BuildContext context) => GameShell(
        matchId: matchId,
        title: 'Mulino',
        fn: 'mulino-move',
        isMyTurn: (gd, isP1) => gd['turn'] == (isP1 ? 'w' : 'b'),
        sideP1: 'Bianche',
        sideP2: 'Nere',
        colorP1: Colors.white,
        colorP2: Pal.violet,
        rules: 'Ogni giocatore posiziona 9 pedine. Forma un mulino mettendo tre pedine in linea e rimuovi una pedina avversaria. Dopo il posizionamento si muove lungo le linee; con 3 pedine si può volare in qualsiasi punto libero. Vince chi lascia l’avversario con meno di 3 pedine o senza mosse.',
        hint: 'Posiziona una pedina, oppure seleziona una tua pedina e poi la destinazione.',
        boardBuilder: (_, ctx) => MulinoBoard(ctx: ctx),
      );
}

class MulinoBoard extends StatefulWidget {
  final MatchCtx ctx;
  const MulinoBoard({super.key, required this.ctx});
  @override
  State<MulinoBoard> createState() => _MulinoBoardState();
}

class _MulinoBoardState extends State<MulinoBoard> {
  int? _selected;
  static const points = <Offset>[
    Offset(0, 0), Offset(3, 0), Offset(6, 0), Offset(1, 1), Offset(3, 1), Offset(5, 1), Offset(2, 2), Offset(3, 2), Offset(4, 2),
    Offset(0, 3), Offset(1, 3), Offset(2, 3), Offset(4, 3), Offset(5, 3), Offset(6, 3), Offset(2, 4), Offset(3, 4), Offset(4, 4),
    Offset(1, 5), Offset(3, 5), Offset(5, 5), Offset(0, 6), Offset(3, 6), Offset(6, 6),
  ];

  @override
  Widget build(BuildContext context) {
    final c = widget.ctx;
    final b = c.board;
    final me = c.isP1 ? 'w' : 'b';
    final phase = c.gd['phase'] ?? 'placing';
    final removing = c.myTurn && c.gd['pending_remove'] == me;
    final w = b.split('').where((p) => p == 'w').length;
    final bl = b.split('').where((p) => p == 'b').length;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Bianche $w', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(width: 24),
        Text('Nere $bl', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 5),
      Text(removing ? 'Hai formato un mulino: rimuovi una pedina avversaria' : (phase == 'placing' ? 'Posizionamento' : 'Movimento'), style: TextStyle(color: removing ? Pal.gold : Colors.white60, fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (_, box) {
                final side = box.maxWidth;
                final unit = side / 6;
                return Stack(children: [
                  Positioned.fill(child: CustomPaint(painter: _MillPainter())),
                  for (var i = 0; i < 24; i++)
                    Positioned(
                      left: points[i].dx * unit - 20,
                      top: points[i].dy * unit - 20,
                      width: 40,
                      height: 40,
                      child: GestureDetector(onTap: () => _tap(i), child: _piece(b[i], _selected == i, removing && b[i] != '.' && b[i] != me)),
                    ),
                ]);
              },
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(c.myTurn ? (removing ? 'Scegli la pedina da togliere' : 'Il tuo turno') : 'Turno avversario', style: const TextStyle(color: Colors.white60, fontSize: 12)),
    ]);
  }

  Widget _piece(String p, bool selected, bool target) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p == '.' ? (target ? Pal.red.withValues(alpha: 0.55) : Colors.white12) : (p == 'w' ? Colors.white : Pal.violet),
          border: Border.all(color: selected ? Pal.cyan : (target ? Pal.gold : Colors.white38), width: selected || target ? 3 : 1),
          boxShadow: p == '.' ? null : const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 2))],
        ),
      );

  void _tap(int i) {
    final c = widget.ctx;
    if (!c.myTurn || c.busy) return;
    final me = c.isP1 ? 'w' : 'b';
    if (c.gd['pending_remove'] == me) {
      if (c.board[i] != '.' && c.board[i] != me) {
        Sfx.i.play('capture', haptic: true);
        c.call('remove', {'cell': i});
      }
      return;
    }
    final phase = c.gd['phase'] ?? 'placing';
    if (phase == 'placing') {
      if (c.board[i] == '.') {
        Sfx.i.play('move', haptic: true);
        c.call('place', {'cell': i});
      }
      return;
    }
    if (_selected == null) {
      if (c.board[i] == me) setState(() => _selected = i);
      return;
    }
    if (c.board[i] == me) return setState(() => _selected = i);
    if (c.board[i] == '.') {
      Sfx.i.play('move', haptic: true);
      c.call('move', {'from': _selected, 'to': i});
      setState(() => _selected = null);
    }
  }
}

class _MillPainter extends CustomPainter {
  static const lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], [9, 10, 11], [12, 13, 14], [15, 16, 17], [18, 19, 20], [21, 22, 23],
    [0, 9, 21], [3, 10, 18], [6, 11, 15], [1, 4, 7], [16, 19, 22], [2, 14, 23], [5, 13, 20], [8, 12, 17],
  ];
  static const points = _MulinoBoardState.points;
  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 6;
    final p = Paint()..color = Pal.gold.withValues(alpha: 0.65)..strokeWidth = 3..style = PaintingStyle.stroke;
    for (final line in lines) {
      final a = points[line.first], b = points[line.last];
      canvas.drawLine(Offset(a.dx * u, a.dy * u), Offset(b.dx * u, b.dy * u), p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
