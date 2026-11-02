import 'package:flutter/material.dart';
import '../audio.dart';
import '../widgets.dart';

const _kRed = Color(0xFFFF4D5E);
const _kYellow = Color(0xFFFFD23F);

class Forza4Screen extends StatelessWidget {
  final String matchId;
  const Forza4Screen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      matchId: matchId,
      title: 'Forza 4',
      fn: 'forza4-move',
      isMyTurn: (gd, isP1) => gd['turn'] == (isP1 ? 'r' : 'y'),
      sideP1: 'Rosso',
      sideP2: 'Giallo',
      colorP1: _kRed,
      colorP2: _kYellow,
      rules: 'Fai cadere un disco per turno in una colonna. Vince chi allinea 4 dischi del proprio colore in orizzontale, verticale o diagonale. Se la griglia si riempie è pareggio.',
      hint: 'Tocca una colonna per far cadere il disco.',
      boardBuilder: (_, ctx) => Forza4Board(ctx: ctx),
    );
  }
}

class Forza4Board extends StatefulWidget {
  final MatchCtx ctx;
  const Forza4Board({super.key, required this.ctx});
  @override
  State<Forza4Board> createState() => _Forza4BoardState();
}

class _Forza4BoardState extends State<Forza4Board> with SingleTickerProviderStateMixin {
  late final AnimationController _drop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650), value: 1);
  int _dropIdx = -1;
  int _hoverCol = -1;

  @override
  void dispose() {
    _drop.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(Forza4Board old) {
    super.didUpdateWidget(old);
    final a = old.ctx.board, b = widget.ctx.board;
    if (a != b && a.length == b.length) {
      for (var i = 0; i < b.length; i++) {
        if (a[i] == '.' && b[i] != '.') {
          _dropIdx = i;
          _drop.forward(from: 0);
          break;
        }
      }
    }
  }

  void _play(int col) {
    final c = widget.ctx;
    if (!c.myTurn || c.busy) return;
    Sfx.i.play('drop', haptic: true);
    setState(() => _hoverCol = col);
    c.call('move', {'col': col});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.ctx;
    return AspectRatio(
      aspectRatio: 7 / 6.8,
      child: LayoutBuilder(builder: (_, box) {
        final cell = box.maxWidth / 7;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final col = (d.localPosition.dx / cell).floor().clamp(0, 6).toInt();
            setState(() => _hoverCol = col);
          },
          onTapUp: (d) => _play((d.localPosition.dx / cell).floor().clamp(0, 6).toInt()),
          onTapCancel: () => setState(() => _hoverCol = -1),
          child: AnimatedBuilder(
            animation: _drop,
            builder: (_, __) => CustomPaint(
              painter: _F4Painter(
                board: c.board,
                dropIdx: _dropIdx,
                dropT: Curves.bounceOut.transform(_drop.value),
                hoverCol: c.myTurn ? _hoverCol : -1,
                finished: c.finished,
                myColor: c.isP1 ? _kRed : _kYellow,
                myTurn: c.myTurn,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _F4Painter extends CustomPainter {
  final String board;
  final int dropIdx;
  final double dropT;
  final int hoverCol;
  final bool finished, myTurn;
  final Color myColor;
  _F4Painter({
    required this.board,
    required this.dropIdx,
    required this.dropT,
    required this.hoverCol,
    required this.finished,
    required this.myColor,
    required this.myTurn,
  });

  // Quattro in fila (solo per evidenziare: l'esito vero lo decide il server).
  Set<int> _winCells() {
    const dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];
    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 7; c++) {
        final ch = board[r * 7 + c];
        if (ch == '.') continue;
        for (final (dr, dc) in dirs) {
          final cells = <int>[];
          for (var k = 0; k < 4; k++) {
            final rr = r + dr * k, cc = c + dc * k;
            if (rr < 0 || rr > 5 || cc < 0 || cc > 6 || board[rr * 7 + cc] != ch) break;
            cells.add(rr * 7 + cc);
          }
          if (cells.length == 4) return cells.toSet();
        }
      }
    }
    return {};
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 7;
    final top = size.height - cell * 6; // spazio sopra per il disco "fantasma"
    final bodyRect = Rect.fromLTWH(0, top, size.width, cell * 6);
    final rr = RRect.fromRectAndRadius(bodyRect, const Radius.circular(18));

    // anteprima del disco sopra la colonna toccata
    if (hoverCol >= 0 && myTurn) {
      _disc(canvas, Offset(hoverCol * cell + cell / 2, top - cell * 0.4), cell * 0.38, myColor, 0.7);
    }

    // dischi (dietro alla plancia)
    final win = finished ? _winCells() : <int>{};
    for (var i = 0; i < 42; i++) {
      final ch = board[i];
      if (ch == '.') continue;
      final r = i ~/ 7, c = i % 7;
      final cx = c * cell + cell / 2;
      var cy = top + r * cell + cell / 2;
      if (i == dropIdx && dropT < 1) {
        final startY = top - cell * 0.5;
        cy = startY + (cy - startY) * dropT;
      }
      _disc(canvas, Offset(cx, cy), cell * 0.38, ch == 'r' ? _kRed : _kYellow, 1);
      if (win.contains(i)) {
        canvas.drawCircle(
          Offset(cx, cy),
          cell * 0.43,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = Colors.white
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
        );
      }
    }

    // plancia blu con i fori
    final holes = Path();
    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 7; c++) {
        holes.addOval(Rect.fromCircle(center: Offset(c * cell + cell / 2, top + r * cell + cell / 2), radius: cell * 0.4));
      }
    }
    final boardPath = Path.combine(PathOperation.difference, Path()..addRRect(rr), holes);
    canvas.drawShadow(boardPath, Colors.black, 8, true);
    canvas.drawPath(
      boardPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F5BFF), Color(0xFF1B2FA8)],
        ).createShader(bodyRect),
    );
    canvas.drawPath(
      boardPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.18),
    );
    // bordino interno dei fori
    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 7; c++) {
        canvas.drawCircle(
          Offset(c * cell + cell / 2, top + r * cell + cell / 2),
          cell * 0.4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = const Color(0xFF14207A),
        );
      }
    }
  }

  void _disc(Canvas canvas, Offset c, double r, Color col, double alpha) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [
            Color.lerp(col, Colors.white, 0.45)!.withValues(alpha: alpha),
            col.withValues(alpha: alpha),
            Color.lerp(col, Colors.black, 0.35)!.withValues(alpha: alpha),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black.withValues(alpha: 0.18 * alpha),
    );
  }

  @override
  bool shouldRepaint(_F4Painter o) =>
      o.board != board || o.dropT != dropT || o.dropIdx != dropIdx || o.hoverCol != hoverCol || o.finished != finished || o.myTurn != myTurn;
}
