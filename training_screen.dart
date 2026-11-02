import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio.dart';
import '../theme.dart';
import '../widgets.dart';

/// Partite locali: non usa Supabase e non modifica Gemme, ELO, XP o statistiche.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});
  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  String _game = 'Tris';
  int _level = 1;

  @override
  Widget build(BuildContext context) {
    return GScaffold(
      appBar: AppBar(
        title: const Text('Allenamento vs CPU'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Nuova partita', onPressed: _reset),
          const MuteButton(),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
          child: Column(children: [
            const Text('Partita locale: non cambia Gemme, ELO, XP o classifica.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 12),
            _choiceRow('Gioco', ['Dama', 'Forza 4', 'Tris'], _game, (v) {
              setState(() => _game = v);
            }),
            const SizedBox(height: 8),
            _choiceRow('Difficoltà', ['Facile', 'Medio', 'Difficile', 'Pro'], ['Facile', 'Medio', 'Difficile', 'Pro'][_level], (v) {
              setState(() => _level = ['Facile', 'Medio', 'Difficile', 'Pro'].indexOf(v));
            }),
            const SizedBox(height: 14),
            Expanded(child: _board()),
          ]),
        ),
      ),
    );
  }

  Widget _choiceRow(String title, List<String> values, String selected, ValueChanged<String> onChanged) {
    return Row(children: [
      SizedBox(width: 78, child: Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12))),
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final value in values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(value),
                  selected: selected == value,
                  onSelected: (_) {
                    Sfx.i.play('tap');
                    onChanged(value);
                  },
                ),
              ),
          ]),
        ),
      ),
    ]);
  }

  Widget _board() {
    return switch (_game) {
      'Dama' => _DamaTraining(key: ValueKey('dama-$_level'), level: _level),
      'Forza 4' => _ConnectFourTraining(key: ValueKey('f4-$_level'), level: _level),
      _ => _TicTacToeTraining(key: ValueKey('tris-$_level'), level: _level),
    };
  }

  void _reset() => setState(() {});
}

class _TicTacToeTraining extends StatefulWidget {
  final int level;
  const _TicTacToeTraining({super.key, required this.level});
  @override
  State<_TicTacToeTraining> createState() => _TicTacToeTrainingState();
}

class _TicTacToeTrainingState extends State<_TicTacToeTraining> {
  List<String> _b = List.filled(9, '.');
  bool _busy = false;
  String _message = 'Il tuo turno: X';

  List<int> _moves(String mark) => [for (var i = 0; i < 9; i++) if (_b[i] == '.') i];
  bool _win(String m) => const [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]
      .any((l) => l.every((i) => _b[i] == m));

  void _tap(int i) {
    if (_busy || _b[i] != '.' || _message != 'Il tuo turno: X') return;
    setState(() => _b[i] = 'X');
    Sfx.i.play('move', haptic: true);
    if (_win('X')) return setState(() => _message = 'Hai vinto!');
    if (_moves('O').isEmpty) return setState(() => _message = 'Patta.');
    setState(() {
      _busy = true;
      _message = 'La CPU sta pensando…';
    });
    Future<void>.delayed(const Duration(milliseconds: 420), _cpu);
  }

  Future<void> _cpu() async {
    if (!mounted) return;
    final move = _bestMove();
    setState(() {
      _b[move] = 'O';
      _busy = false;
      _message = _win('O') ? 'Vince la CPU.' : (_moves('X').isEmpty ? 'Patta.' : 'Il tuo turno: X');
    });
    Sfx.i.play('move', haptic: true);
  }

  int _bestMove() {
    final free = _moves('O');
    if (free.isEmpty) return 0;
    if (widget.level == 0) return free[math.Random().nextInt(free.length)];
    if (widget.level < 3) {
      for (final i in free) {
        _b[i] = 'O';
        final w = _win('O');
        _b[i] = '.';
        if (w) return i;
      }
      if (widget.level >= 1) {
        for (final i in free) {
          _b[i] = 'X';
          final w = _win('X');
          _b[i] = '.';
          if (w) return i;
        }
      }
      if (widget.level == 2 && _b[4] == '.') return 4;
      return free[math.Random().nextInt(free.length)];
    }
    var best = -1000, selected = free.first;
    for (final i in free) {
      _b[i] = 'O';
      final score = _minimax(false);
      _b[i] = '.';
      if (score > best) {
        best = score;
        selected = i;
      }
    }
    return selected;
  }

  int _minimax(bool cpu) {
    if (_win('O')) return 10;
    if (_win('X')) return -10;
    final free = _moves('O');
    if (free.isEmpty) return 0;
    var best = cpu ? -1000 : 1000;
    for (final i in free) {
      _b[i] = cpu ? 'O' : 'X';
      final score = _minimax(!cpu);
      _b[i] = '.';
      best = cpu ? math.max(best, score) : math.min(best, score);
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(_message, style: TextStyle(color: _message.contains('vinto') ? Pal.green : Colors.white70, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: GlassCard(
              padding: const EdgeInsets.all(10),
              child: GridView.count(
                crossAxisCount: 3,
                physics: const NeverScrollableScrollPhysics(),
                children: [for (var i = 0; i < 9; i++) _cell(i)],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      const Text('Tu giochi con X · la CPU con O', style: TextStyle(color: Colors.white54, fontSize: 12)),
    ]);
  }

  Widget _cell(int i) => GestureDetector(
        onTap: () => _tap(i),
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.white.withValues(alpha: 0.04)),
          child: Center(
            child: Text(_b[i] == '.' ? '' : _b[i], style: TextStyle(fontSize: 50, fontWeight: FontWeight.w900, color: _b[i] == 'X' ? Pal.cyan : Pal.pink)),
          ),
        ),
      );
}

class _ConnectFourTraining extends StatefulWidget {
  final int level;
  const _ConnectFourTraining({super.key, required this.level});
  @override
  State<_ConnectFourTraining> createState() => _ConnectFourTrainingState();
}

class _ConnectFourTrainingState extends State<_ConnectFourTraining> {
  List<String> _b = List.filled(42, '.');
  bool _busy = false;
  String _message = 'Il tuo turno: rosso';

  List<int> _valid() => [for (var c = 0; c < 7; c++) if (_b[c] == '.') c];
  int _drop(int c, String p) {
    for (var r = 5; r >= 0; r--) {
      final i = r * 7 + c;
      if (_b[i] == '.') {
        _b[i] = p;
        return i;
      }
    }
    return -1;
  }

  bool _win(String p) {
    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 7; c++) {
        for (final d in const [(0, 1), (1, 0), (1, 1), (1, -1)]) {
          final cells = [for (var k = 0; k < 4; k++) (r + d.$1 * k) * 7 + c + d.$2 * k];
          if (cells.every((i) => i >= 0 && i < 42 && (i ~/ 7 == r + d.$1 * (cells.indexOf(i))) && _b[i] == p)) return true;
        }
      }
    }
    return false;
  }

  void _tap(int c) {
    if (_busy || !_valid().contains(c) || _message != 'Il tuo turno: rosso') return;
    setState(() => _drop(c, 'r'));
    Sfx.i.play('drop', haptic: true);
    if (_win('r')) return setState(() => _message = 'Hai vinto!');
    if (_valid().isEmpty) return setState(() => _message = 'Patta.');
    setState(() {
      _busy = true;
      _message = 'La CPU sta pensando…';
    });
    Future<void>.delayed(const Duration(milliseconds: 450), _cpu);
  }

  Future<void> _cpu() async {
    if (!mounted) return;
    final c = _bestColumn();
    setState(() {
      _drop(c, 'y');
      _busy = false;
      _message = _win('y') ? 'Vince la CPU.' : (_valid().isEmpty ? 'Patta.' : 'Il tuo turno: rosso');
    });
    Sfx.i.play('drop', haptic: true);
  }

  int _bestColumn() {
    final valid = _valid();
    if (valid.isEmpty) return 0;
    if (widget.level == 0) return valid[math.Random().nextInt(valid.length)];
    for (final c in valid) {
      _drop(c, 'y');
      final w = _win('y');
      _b[c] = '.';
      if (w) return c;
    }
    if (widget.level >= 1) {
      for (final c in valid) {
        _drop(c, 'r');
        final w = _win('r');
        _b[c] = '.';
        if (w) return c;
      }
    }
    if (widget.level >= 2 && valid.contains(3)) return 3;
    return valid[math.Random().nextInt(valid.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(_message, style: TextStyle(color: _message.contains('vinto') ? Pal.green : Colors.white70, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Expanded(child: Center(child: AspectRatio(aspectRatio: 7 / 6, child: GestureDetector(
        onTapUp: (d) {
          final c = (d.localPosition.dx / (MediaQuery.sizeOf(context).width / 7)).floor().clamp(0, 6);
          _tap(c);
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF2439A4), borderRadius: BorderRadius.circular(20)),
          child: GridView.count(
            crossAxisCount: 7,
            physics: const NeverScrollableScrollPhysics(),
            children: [for (final p in _b) Center(child: Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, color: p == '.' ? const Color(0xFF111B69) : (p == 'r' ? const Color(0xFFFF4D5E) : const Color(0xFFFFD23F)), border: Border.all(color: Colors.white24)),
            ))],
          ),
        ),
      )))),
      const SizedBox(height: 10),
      const Text('Tocca una colonna · tu rosso, CPU giallo', style: TextStyle(color: Colors.white54, fontSize: 12)),
    ]);
  }
}

class _DamaTraining extends StatefulWidget {
  final int level;
  const _DamaTraining({super.key, required this.level});
  @override
  State<_DamaTraining> createState() => _DamaTrainingState();
}

class _DamaTrainingState extends State<_DamaTraining> {
  String _b = _initialBoard();
  int? _selected;
  bool _busy = false;
  String _message = 'Il tuo turno: bianche';

  static String _initialBoard() {
    final board = List<String>.filled(64, '.');
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 8; col++) {
        if ((row + col).isOdd) board[row * 8 + col] = 'b';
      }
    }
    for (var row = 5; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        if ((row + col).isOdd) board[row * 8 + col] = 'w';
      }
    }
    return board.join();
  }

  List<List<int>> _moves(String side) {
    final out = <List<int>>[];
    for (var i = 0; i < 64; i++) {
      final p = _b[i];
      if (p.toLowerCase() != side) continue;
      final king = p == side.toUpperCase();
      final row = i ~/ 8, col = i % 8;
      final dirs = <int>[if (king || side == 'w') -1, if (king || side == 'b') 1];
      for (final dr in dirs) {
        for (final dc in const [-1, 1]) {
          final r = row + dr, c = col + dc;
          if (r >= 0 && r < 8 && c >= 0 && c < 8) {
            final to = r * 8 + c;
            if (_b[to] == '.') out.add([i, to]);
            else if (_b[to].toLowerCase() != side) {
              final rr = r + dr, cc = c + dc;
              if (rr >= 0 && rr < 8 && cc >= 0 && cc < 8 && _b[rr * 8 + cc] == '.') out.add([i, rr * 8 + cc]);
            }
          }
        }
      }
    }
    return out;
  }

  bool _capture(List<int> m) => (m[1] ~/ 8 - m[0] ~/ 8).abs() == 2;

  void _tap(int i) {
    if (_busy || _message != 'Il tuo turno: bianche') return;
    if (_selected == null) {
      if (_b[i].toLowerCase() == 'w') setState(() => _selected = i);
      return;
    }
    final move = [_selected!, i];
    if (!_moves('w').any((m) => m[0] == move[0] && m[1] == move[1])) {
      setState(() => _selected = null);
      return;
    }
    _apply(move, 'w');
    Sfx.i.play(_capture(move) ? 'capture' : 'move', haptic: true);
    if (_finished('w')) return;
    setState(() {
      _busy = true;
      _message = 'La CPU sta pensando…';
    });
    Future<void>.delayed(const Duration(milliseconds: 500), _cpu);
  }

  void _apply(List<int> m, String side) {
    final chars = _b.split('');
    var p = chars[m[0]];
    chars[m[0]] = '.';
    if (_capture(m)) chars[((m[0] ~/ 8 + m[1] ~/ 8) ~/ 2) * 8 + (m[0] % 8 + m[1] % 8) ~/ 2] = '.';
    final row = m[1] ~/ 8;
    if (side == 'w' && row == 0) p = 'W';
    if (side == 'b' && row == 7) p = 'B';
    chars[m[1]] = p;
    _b = chars.join();
  }

  Future<void> _cpu() async {
    if (!mounted) return;
    final moves = _moves('b');
    if (moves.isEmpty) return setState(() { _busy = false; _message = 'Hai vinto!'; });
    final captures = moves.where(_capture).toList();
    final pool = widget.level == 0 ? moves : (captures.isNotEmpty ? captures : moves);
    final move = pool[math.Random().nextInt(pool.length)];
    setState(() {
      _apply(move, 'b');
      _busy = false;
      _message = _finished('b') ? 'Vince la CPU.' : 'Il tuo turno: bianche';
    });
    Sfx.i.play(_capture(move) ? 'capture' : 'move', haptic: true);
  }

  bool _finished(String side) {
    final has = _b.split('').any((p) => p.toLowerCase() == side);
    if (!has) {
      _message = side == 'w' ? 'Vince la CPU.' : 'Hai vinto!';
      return true;
    }
    final other = side == 'w' ? 'b' : 'w';
    if (_moves(other).isEmpty) {
      _message = side == 'w' ? 'Hai vinto!' : 'Vince la CPU.';
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cell = MediaQuery.sizeOf(context).width / 8;
    return Column(children: [
      Text(_message, style: TextStyle(color: _message.contains('Hai vinto') ? Pal.green : Colors.white70, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: GestureDetector(
        onTapUp: (d) => _tap((d.localPosition.dy / cell).floor().clamp(0, 7) * 8 + (d.localPosition.dx / cell).floor().clamp(0, 7)),
        child: GridView.count(
          crossAxisCount: 8,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (var i = 0; i < 64; i++) Container(
            color: ((i ~/ 8 + i % 8) % 2 == 0) ? const Color(0xFFEBD8B4) : const Color(0xFF70462F),
            child: _b[i] == '.' ? null : Center(child: Container(
              width: cell * 0.68,
              height: cell * 0.68,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _b[i].toLowerCase() == 'w' ? Colors.white : Pal.violet, border: Border.all(color: _selected == i ? Pal.cyan : Colors.white30, width: _selected == i ? 4 : 1)),
              child: (_b[i] == 'W' || _b[i] == 'B') ? const Icon(Icons.workspace_premium, color: Pal.gold, size: 20) : null,
            )),
          )],
        ),
      )))),
      const SizedBox(height: 10),
      const Text('Tocca una pedina e poi la casa di arrivo · tu bianche', style: TextStyle(color: Colors.white54, fontSize: 12)),
    ]);
  }
}
