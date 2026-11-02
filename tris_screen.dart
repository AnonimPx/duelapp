import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio.dart';
import '../theme.dart';
import '../widgets.dart';

class TrisScreen extends StatelessWidget {
  final String matchId;
  const TrisScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      matchId: matchId,
      title: 'Tris Pro',
      fn: 'tris-move',
      isMyTurn: (gd, isP1) => gd['turn'] == (isP1 ? 'x' : 'o'),
      sideP1: 'X',
      sideP2: 'O',
      colorP1: Pal.cyan,
      colorP2: Pal.pink,
      rules: 'Tris classico. X e O mettono un segno in una casella libera. Vince chi allinea tre segni. Se la griglia si riempie senza vincitori è patta e la partita riparte automaticamente dopo un secondo.',
      hint: 'Tocca una casella libera. Tu giochi X.',
      boardBuilder: (_, ctx) => TrisBoard(ctx: ctx),
    );
  }
}

class TrisBoard extends StatelessWidget {
  final MatchCtx ctx;
  const TrisBoard({super.key, required this.ctx});

  static const _lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6],
  ];

  List<int> _winLine(String b) {
    for (final l in _lines) {
      if (b[l[0]] != '.' && b[l[0]] == b[l[1]] && b[l[1]] == b[l[2]]) return l;
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final b = ctx.board;
    final win = ctx.finished ? _winLine(b) : const <int>[];
    final drawUntil = (ctx.gd['draw_notice_until'] as num?)?.toInt() ?? 0;
    final showDraw = drawUntil > DateTime.now().millisecondsSinceEpoch;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Pal.border),
        ),
        child: LayoutBuilder(builder: (_, box) {
          return Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            GridView.count(
              crossAxisCount: 3,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(9, (i) {
                final ch = b[i];
                final canTap = ctx.myTurn && !ctx.busy && ch == '.';
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: canTap
                      ? () {
                          Sfx.i.play('move', haptic: true);
                          ctx.call('move', {'cell': i});
                        }
                      : null,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: win.contains(i) ? Pal.gold.withValues(alpha: 0.22) : Colors.transparent,
                    ),
                    child: ch == '.'
                        ? const SizedBox.expand()
                        : _Mark(key: ValueKey('$i$ch'), isX: ch == 'x'),
                  ),
                );
              }),
            ),
            if (showDraw)
              const Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xEE1A1E3C), borderRadius: BorderRadius.all(Radius.circular(16))),
                  child: Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14), child: Text('Patta', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Pal.gold))),
                ),
              ),
          ]);
        }),
      ),
    );
  }
}

/// Segno con animazione di comparsa e sbiadimento per quello che sta per sparire.
class _Mark extends StatelessWidget {
  final bool isX;
  const _Mark({super.key, required this.isX});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (_, t, __) => Transform.scale(
        scale: t.clamp(0.0, 1.2).toDouble(),
          child: CustomPaint(
            size: Size.infinite,
            painter: _MarkPainter(isX: isX, color: isX ? Pal.cyan : Pal.pink),
          ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final bool isX;
  final Color color;
  _MarkPainter({required this.isX, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * 0.30;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.26
      ..strokeCap = StrokeCap.round;
    final tint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.42
      ..strokeCap = StrokeCap.round;
    void draw(Paint p) {
      if (isX) {
        canvas.drawLine(c + Offset(-r, -r), c + Offset(r, r), p);
        canvas.drawLine(c + Offset(r, -r), c + Offset(-r, r), p);
      } else {
        canvas.drawCircle(c, r * 1.1, p);
      }
    }

    draw(glow);
    draw(tint);
    draw(line);
  }

  @override
  bool shouldRepaint(_MarkPainter o) => o.isX != isX || o.color != color;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..shader = const LinearGradient(colors: [Pal.violet, Pal.cyan]).createShader(Offset.zero & size)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    final m = 6.0;
    canvas.drawLine(Offset(w / 3, m), Offset(w / 3, h - m), p);
    canvas.drawLine(Offset(2 * w / 3, m), Offset(2 * w / 3, h - m), p);
    canvas.drawLine(Offset(m, h / 3), Offset(w - m, h / 3), p);
    canvas.drawLine(Offset(m, 2 * h / 3), Offset(w - m, 2 * h / 3), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
