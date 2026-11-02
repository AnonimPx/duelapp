import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../audio.dart';
import '../theme.dart';
import '../widgets.dart';

class DamaScreen extends StatelessWidget {
  final String matchId;
  const DamaScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      matchId: matchId,
      title: 'Dama Italiana',
      fn: 'dama-move',
      isMyTurn: (gd, isP1) => gd['turn'] == (isP1 ? 'w' : 'b'),
      sideP1: 'Bianco',
      sideP2: 'Nero',
      colorP1: const Color(0xFFF1F3FF),
      colorP2: Pal.violet,
      rules: 'Dama italiana. Il bianco muove per primo, in avanti in diagonale di una casa.\n• La presa è obbligatoria.\n• La pedina non può mangiare la dama.\n• Si può mangiare più pezzi in una sola mossa: tocca ogni casa di arrivo e conferma.\n• Se una pedina arriva all\'ultima riga diventa dama (muove anche all\'indietro) e la mossa termina.\n• Vince chi blocca o elimina tutti i pezzi avversari.',
      hint: 'Tocca una tua pedina, poi la casa di arrivo. Prese multiple: tocca ogni casa e conferma.',
      boardBuilder: (_, ctx) => DamaBoard(ctx: ctx),
    );
  }
}

class DamaBoard extends StatefulWidget {
  final MatchCtx ctx;
  const DamaBoard({super.key, required this.ctx});
  @override
  State<DamaBoard> createState() => _DamaBoardState();
}

class _DamaBoardState extends State<DamaBoard> {
  List<int> _path = [];

  @override
  void didUpdateWidget(DamaBoard old) {
    super.didUpdateWidget(old);
    if (!widget.ctx.myTurn && _path.isNotEmpty) _path = [];
  }

  // Il client NON decide nulla: invia solo il percorso, il server lo valida.
  void _tap(int idx) {
    final c = widget.ctx;
    if (!c.myTurn || c.busy) return;
    final me = c.isP1 ? 'w' : 'b';
    final p = c.board[idx];
    final mine = p != '.' && p.toLowerCase() == me;
    if (_path.isEmpty) {
      if (mine) {
        setState(() => _path = [idx]);
        Sfx.i.play('tap', haptic: true);
      }
      return;
    }
    if (mine && _path.length == 1) {
      setState(() => _path = idx == _path.first ? [] : [idx]);
      Sfx.i.play('tap');
      return;
    }
    if (p == '.') {
      final next = [..._path, idx];
      setState(() => _path = next);
      if (next.length == 2 && ((next[1] ~/ 8) - (next[0] ~/ 8)).abs() == 1) {
        _send(next);
      } else {
        Sfx.i.play('tap');
      }
    }
  }

  Future<void> _send(List<int> path) async {
    final jump = path.length > 2 || ((path[1] ~/ 8) - (path[0] ~/ 8)).abs() == 2;
    Sfx.i.play(jump ? 'capture' : 'move', haptic: true);
    await widget.ctx.call('move', {'path': path});
    if (mounted) setState(() => _path = []);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.ctx;
    final flip = !c.isP1; // il nero vede la scacchiera ruotata
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(builder: (_, box) {
            final cell = box.maxWidth / 8;
            return GestureDetector(
              onTapUp: (d) {
                final col = (d.localPosition.dx / cell).floor().clamp(0, 7).toInt();
                final row = (d.localPosition.dy / cell).floor().clamp(0, 7).toInt();
                final i = row * 8 + col;
                _tap(flip ? 63 - i : i);
              },
              child: CustomPaint(
                painter: _DamaPainter(board: c.board, flip: flip, path: _path, changed: c.changed),
              ),
            );
          }),
        ),
      ),
      if (c.myTurn && _path.length >= 2 && !c.busy)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton(onPressed: () => setState(() => _path = []), child: const Text('Annulla')),
            const SizedBox(width: 12),
            FilledButton(onPressed: () => _send(List<int>.from(_path)), child: const Text('Conferma presa')),
          ]),
        ),
      if (c.myTurn && _path.length == 1)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: OutlinedButton(onPressed: () => setState(() => _path = []), child: const Text('Annulla selezione')),
        ),
    ]);
  }
}

class _DamaPainter extends CustomPainter {
  final String board;
  final bool flip;
  final List<int> path;
  final Set<int> changed;
  _DamaPainter({required this.board, required this.flip, required this.path, required this.changed});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cell = s / 8;
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s, s), const Radius.circular(14));

    // ombra e cornice
    canvas.drawRRect(
      rr.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black54
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.save();
    canvas.clipRRect(rr);

    final light = Paint()..color = const Color(0xFFEBD8B4);
    final dark = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8A5A3C), Color(0xFF6B4129)],
      ).createShader(Rect.fromLTWH(0, 0, s, s));

    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final i = r * 8 + c;
        final bi = flip ? 63 - i : i;
        final isDark = ((bi ~/ 8) + (bi % 8)) % 2 == 1;
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
        canvas.drawRect(rect, isDark ? dark : light);
        if (changed.contains(bi) && isDark) {
          canvas.drawRect(rect, Paint()..color = Pal.gold.withValues(alpha: 0.38));
        }
        final k = path.indexOf(bi);
        if (k >= 0) {
          canvas.drawRect(rect, Paint()..color = Pal.cyan.withValues(alpha: 0.5));
          canvas.drawRect(
            rect.deflate(1.5),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Pal.cyan,
          );
        }
      }
    }

    // pedine
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final i = r * 8 + c;
        final bi = flip ? 63 - i : i;
        final p = board[bi];
        if (p == '.') continue;
        _piece(canvas, Offset(c * cell + cell / 2, r * cell + cell / 2), cell * 0.39, p);
      }
    }

    // numeri del percorso (prese multiple)
    if (path.length > 2) {
      for (var k = 1; k < path.length; k++) {
        final bi = path[k];
        final i = flip ? 63 - bi : bi;
        final center = Offset((i % 8) * cell + cell / 2, (i ~/ 8) * cell + cell / 2);
        canvas.drawCircle(center, cell * 0.15, Paint()..color = Pal.cyan);
        final tp = TextPainter(
          text: TextSpan(text: '$k', style: TextStyle(color: Colors.black, fontSize: cell * 0.2, fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      }
    }
    canvas.restore();

    canvas.drawRRect(
      rr.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF3B2416),
    );
  }

  void _piece(Canvas canvas, Offset c, double r, String p) {
    final white = p.toLowerCase() == 'w';
    // ombra
    canvas.drawCircle(
      c + Offset(0, r * 0.18),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        colors: white
            ? const [Color(0xFFFFFFFF), Color(0xFFE2E4F2), Color(0xFFA9AECB)]
            : const [Color(0xFF6A5BA8), Color(0xFF2A2250), Color(0xFF0F0B24)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, body);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = white ? Colors.white70 : Pal.violet.withValues(alpha: 0.8),
    );
    canvas.drawCircle(
      c,
      r * 0.66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = (white ? Colors.black : Colors.white).withValues(alpha: 0.18),
    );
    if (p == 'W' || p == 'B') {
      final u = r * 0.55;
      final crown = Path()
        ..moveTo(c.dx - u, c.dy + u * 0.6)
        ..lineTo(c.dx - u, c.dy - u * 0.5)
        ..lineTo(c.dx - u * 0.45, c.dy + u * 0.05)
        ..lineTo(c.dx, c.dy - u * 0.8)
        ..lineTo(c.dx + u * 0.45, c.dy + u * 0.05)
        ..lineTo(c.dx + u, c.dy - u * 0.5)
        ..lineTo(c.dx + u, c.dy + u * 0.6)
        ..close();
      canvas.drawPath(crown, Paint()..color = Pal.gold);
      canvas.drawPath(
        crown,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF9A6B00),
      );
    }
  }

  @override
  bool shouldRepaint(_DamaPainter o) =>
      o.board != board || o.flip != flip || !listEquals(o.path, path) || !setEquals(o.changed, changed);
}
