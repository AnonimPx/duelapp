import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'audio.dart';
import 'avatars.dart';
import 'connection.dart';
import 'supa.dart';
import 'theme.dart';

/// Snackbar uniforme (con suono di errore opzionale).
void toast(BuildContext context, String m, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: error ? Pal.red : const Color(0xFF2A2F55),
      content: Text(m, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    ));
  if (error) Sfx.i.play('error', haptic: true);
}

/// Scaffold con lo sfondo a gradiente (opaco: le transizioni tra schermate restano pulite).
class GScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  const GScaffold({super.key, this.appBar, required this.body, this.bottomNavigationBar, this.floatingActionButton});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}

/// Interruttore audio (si ricorda la scelta).
class MuteButton extends StatefulWidget {
  const MuteButton({super.key});
  @override
  State<MuteButton> createState() => _MuteButtonState();
}

class _MuteButtonState extends State<MuteButton> {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: Sfx.i.muted ? 'Attiva audio' : 'Disattiva audio',
      icon: Icon(Sfx.i.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
      onPressed: () async {
        await Sfx.i.setMuted(!Sfx.i.muted);
        if (!Sfx.i.muted) Sfx.i.play('tap');
        if (mounted) setState(() {});
      },
    );
  }
}

/// Dati della partita passati alla scacchiera di ogni gioco.
class MatchCtx {
  final Map<String, dynamic> match;
  final Map<String, dynamic> gd;
  final String uid;
  final bool isP1;
  final bool finished;
  final bool myTurn;
  final bool busy;

  /// Indici cambiati dall'ultima mossa (solo per evidenziarla).
  final Set<int> changed;

  /// Invia un'azione all'arbitro sul server (il client non decide nulla).
  final Future<void> Function(String action, [Map<String, dynamic>? extra]) call;

  const MatchCtx({
    required this.match,
    required this.gd,
    required this.uid,
    required this.isP1,
    required this.finished,
    required this.myTurn,
    required this.busy,
    required this.changed,
    required this.call,
  });

  String get board => (gd['board'] as String?) ?? '';
}

/// Struttura comune a tutte le partite: giocatori, turno, risultato, suoni, riconnessione.
class GameShell extends StatefulWidget {
  final String matchId, title, fn;
  final bool Function(Map<String, dynamic> gd, bool isP1) isMyTurn;
  final String sideP1, sideP2;
  final Color colorP1, colorP2;
  final String hint;
  final String rules; // testo regole mostrato dall'icona (i)
  final bool showTurn; // false: nessun indicatore di turno (es. Scacchi)
  final bool serverActions; // false: niente Abbandona/Timeout (es. Scacchi, decide Lichess)
  final Widget Function(BuildContext, MatchCtx) boardBuilder;

  const GameShell({
    super.key,
    required this.matchId,
    required this.title,
    required this.fn,
    required this.isMyTurn,
    required this.sideP1,
    required this.sideP2,
    required this.colorP1,
    required this.colorP2,
    required this.boardBuilder,
    this.hint = '',
    this.serverActions = true,
    this.showTurn = true,
    this.rules = '',
  });

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> with WidgetsBindingObserver {
  static const _timeoutSec = 300;

  Map<String, dynamic>? _m;
  final Map<String, Map<String, dynamic>> _profiles = {};
  Set<int> _changed = {};
  bool _busy = false;
  bool _showResult = false;
  StreamSubscription<Rows>? _sub;
  Timer? _poll, _tick;
  String get _uid => supa.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = resilient(() => supa.from('matches').stream(primaryKey: ['id']).eq('id', widget.matchId)).listen((rows) {
      if (rows.isNotEmpty) _apply(rows.first);
    });
    // Rete di sicurezza: se il realtime si addormenta, rileggo la partita ogni 4 secondi.
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_m == null || _m!['status'] == 'in_progress') _fetch();
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _m != null && _m!['status'] == 'in_progress') setState(() {});
    });
    _fetch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ConnectionMonitor.i.check();
      _fetch();
    }
  }

  Future<void> _fetch() async {
    try {
      final r = await supa.from('matches').select().eq('id', widget.matchId).maybeSingle();
      if (r != null && mounted) _apply(r);
    } catch (_) {}
  }

  Future<void> _loadProfiles(Map<String, dynamic> m) async {
    try {
      final rows = await supa
          .from('users')
          .select('id,username,avatar,avatar_color,elo_global')
          .inFilter('id', [m['player1_id'], m['player2_id']]);
      if (!mounted) return;
      setState(() {
        for (final r in rows) {
          _profiles[r['id'] as String] = Map<String, dynamic>.from(r);
        }
      });
    } catch (_) {}
  }

  int _count(String b) => b.split('').where((c) => c != '.').length;

  void _apply(Map<String, dynamic> m) {
    final old = _m;
    final gd = Map<String, dynamic>.from(m['game_data'] as Map);
    final finished = m['status'] != 'in_progress';
    final isP1 = m['player1_id'] == _uid;
    var changed = _changed;

    if (old != null) {
      final ogd = Map<String, dynamic>.from(old['game_data'] as Map);
      if (jsonEncode(ogd) != jsonEncode(gd)) {
        final ob = (ogd['board'] as String?) ?? '';
        final nb = (gd['board'] as String?) ?? '';
        changed = <int>{};
        if (ob.length == nb.length) {
          for (var i = 0; i < nb.length; i++) {
            if (ob[i] != nb[i]) changed.add(i);
          }
        }
        // Mossa dell'avversario: la mia mossa suona già al tocco.
        if (!finished && widget.isMyTurn(gd, isP1)) {
          final captured = _count(nb) < _count(ob);
          Sfx.i.play(captured ? 'capture' : (widget.fn == 'forza4-move' ? 'drop' : 'move'), haptic: true);
          Future<void>.delayed(const Duration(milliseconds: 260), () => Sfx.i.play('turn'));
        }
      }
      if (old['status'] == 'in_progress' && finished) {
        final w = m['winner_id'];
        Sfx.i.play(w == null ? 'draw' : (w == _uid ? 'win' : 'lose'), haptic: true);
        _showResult = true;
      }
    } else {
      _loadProfiles(m);
    }

    if (!mounted) return;
    setState(() {
      _m = m;
      _changed = changed;
    });
  }

  Future<void> _call(String action, [Map<String, dynamic>? extra]) async {
    setState(() => _busy = true);
    try {
      await supa.functions.invoke(widget.fn, body: {
        'match_id': widget.matchId,
        'action': action,
        ...?extra,
      });
      await _fetch();
    } on FunctionException catch (e) {
      final d = e.details;
      toast(context, errText(d is Map ? d['error'] : d), error: true);
    } catch (e) {
      toast(context, 'Connessione instabile, riprova.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmResign() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abbandonare?'),
        content: const Text('Perderai la puntata.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Pal.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abbandona'),
          ),
        ],
      ),
    );
    if (ok == true) _call('resign');
  }

  int? _timeoutLeft(Map<String, dynamic> gd) {
    final last = num.tryParse('${gd['last_move_at']}');
    if (last == null) return null;
    final elapsed = (DateTime.now().millisecondsSinceEpoch - last) / 1000;
    return (_timeoutSec - elapsed).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    return GScaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        if (widget.rules.isNotEmpty)
          IconButton(
            tooltip: 'Regole',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showRules(context, widget.title, widget.rules),
          ),
        const MuteButton(),
      ]),
      body: m == null ? const Center(child: CircularProgressIndicator()) : _body(m),
    );
  }

  Widget _body(Map<String, dynamic> m) {
    final gd = Map<String, dynamic>.from(m['game_data'] as Map);
    final finished = m['status'] != 'in_progress';
    final isP1 = m['player1_id'] == _uid;
    final turnData = <String, dynamic>{...gd, 'current_user_id': _uid};
    final myTurn = !finished && widget.isMyTurn(turnData, isP1);
    final oppId = (isP1 ? m['player2_id'] : m['player1_id']) as String;
    final ctx = MatchCtx(
      match: m,
      gd: gd,
      uid: _uid,
      isP1: isP1,
      finished: finished,
      myTurn: myTurn,
      busy: _busy,
      changed: _changed,
      call: _call,
    );

    final winner = m['winner_id'];
    final kind = !finished ? '' : (winner == null ? 'draw' : (winner == _uid ? 'win' : 'lose'));
    final left = (!finished && !myTurn) ? _timeoutLeft(gd) : null;

    return Stack(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: Column(children: [
          PlayerCard(
            profile: _profiles[oppId],
            side: isP1 ? widget.sideP2 : widget.sideP1,
            sideColor: isP1 ? widget.colorP2 : widget.colorP1,
            active: widget.showTurn && !finished && !myTurn,
            isMe: false,
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Puntata ', style: TextStyle(color: Colors.white60, fontSize: 12)),
            GemChip(m['stake_gems'] as num),
            const SizedBox(width: 14),
            const Text('Premio ', style: TextStyle(color: Colors.white60, fontSize: 12)),
            GemChip(m['prize_gems'] as num),
          ]),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: widget.boardBuilder(context, ctx),
              ),
            ),
          ),
          if (finished) _resultPill(kind, m) else if (widget.hint.isNotEmpty && myTurn)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(widget.hint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ),
          PlayerCard(
            profile: _profiles[_uid],
            side: isP1 ? widget.sideP1 : widget.sideP2,
            sideColor: isP1 ? widget.colorP1 : widget.colorP2,
            active: widget.showTurn && myTurn,
            isMe: true,
          ),
          const SizedBox(height: 10),
          if (!finished && widget.serverActions)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton.icon(
                onPressed: _busy ? null : _confirmResign,
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Abbandona'),
                style: TextButton.styleFrom(foregroundColor: Pal.red),
              ),
              if (left != null && left > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text('Timeout tra ${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ),
              if (left != null && left <= 0)
                FilledButton.tonal(
                  onPressed: _busy ? null : () => _call('claim_timeout'),
                  child: const Text('Rivendica la vittoria'),
                ),
            ]),
        ]),
      ),
      if (_showResult && finished)
        Positioned.fill(
          child: ResultOverlay(
            kind: kind,
            gems: kind == 'win' ? '+${m['prize_gems']}' : (kind == 'lose' ? '-${m['stake_gems']}' : '0'),
            onClose: () => setState(() => _showResult = false),
            onExit: () => Navigator.of(context).pop(),
          ),
        ),
    ]);
  }

  Widget _resultPill(String kind, Map<String, dynamic> m) {
    final (text, color) = switch (kind) {
      'win' => ('🏆 Hai vinto +${m['prize_gems']} 💎', Pal.green),
      'lose' => ('Hai perso -${m['stake_gems']} 💎', Pal.red),
      _ => ('Pareggio: puntata restituita', Pal.gold),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
    );
  }
}

/// Scheda giocatore: avatar, nick, ELO, lato; si illumina quando tocca a lui.
class PlayerCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final String side;
  final Color sideColor;
  final bool active;
  final bool isMe;
  const PlayerCard({
    super.key,
    required this.profile,
    required this.side,
    required this.sideColor,
    required this.active,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final name = p == null ? '…' : '${p['username']}';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: active ? sideColor.withValues(alpha: 0.14) : Pal.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? sideColor : Pal.border, width: active ? 2 : 1),
        boxShadow: active ? [BoxShadow(color: sideColor.withValues(alpha: 0.35), blurRadius: 18)] : const [],
      ),
      child: Row(children: [
        AvatarCircle(emoji: (p?['avatar'] ?? '🦊') as String, color: (p?['avatar_color'] ?? 'purple') as String, size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isMe ? '$name (tu)' : name,
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('ELO ${p?['elo_global'] ?? '—'}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ),
        if (active)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(isMe ? 'Tocca a te' : 'Sta giocando…',
                style: TextStyle(color: sideColor, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: sideColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: sideColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(side, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

/// Schermata di fine partita con coriandoli (solo se vinci).
class ResultOverlay extends StatefulWidget {
  final String kind; // win | lose | draw
  final String gems;
  final VoidCallback onClose, onExit;
  const ResultOverlay({super.key, required this.kind, required this.gems, required this.onClose, required this.onExit});
  @override
  State<ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<ResultOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (emoji, title, color) = switch (widget.kind) {
      'win' => ('🏆', 'VITTORIA!', Pal.gold),
      'lose' => ('💔', 'Sconfitta', Pal.red),
      _ => ('🤝', 'Pareggio', Pal.cyan),
    };
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Stack(children: [
        if (widget.kind == 'win')
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_c.value)),
              ),
            ),
          ),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: GlassCard(
              margin: const EdgeInsets.all(28),
              padding: const EdgeInsets.all(26),
              tint: const Color(0xE61A1E3C),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(emoji, style: const TextStyle(fontSize: 72)),
                const SizedBox(height: 6),
                Text(title, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color)),
                const SizedBox(height: 10),
                if (widget.kind != 'draw') GemChip(widget.gems, big: true),
                if (widget.kind == 'draw') const Text('Puntata restituita', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 22),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  OutlinedButton(onPressed: widget.onClose, child: const Text('Vedi partita')),
                  const SizedBox(width: 12),
                  FilledButton(onPressed: widget.onExit, child: const Text('Esci')),
                ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);

  static final _rnd = math.Random(7);
  // x, y iniziale, fase, velocita', colore
  static final List<List<double>> _p = List.generate(
    80,
    (_) => [_rnd.nextDouble(), _rnd.nextDouble() * 0.35, _rnd.nextDouble() * 6.28, 0.6 + _rnd.nextDouble() * 0.9, _rnd.nextInt(5).toDouble()],
  );
  static const _cols = [Pal.gold, Pal.pink, Pal.cyan, Pal.green, Pal.violet];

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _p) {
      final x = p[0] * size.width + math.sin(t * 7 + p[2]) * 22;
      final y = (p[1] + t * p[3]) * size.height * 1.15 - 40;
      if (y > size.height) continue;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 9 + p[2]);
      canvas.drawRect(
        const Rect.fromLTWH(-4, -2, 8, 4),
        Paint()..color = _cols[p[4].toInt()].withValues(alpha: (1 - t * 0.5).clamp(0.0, 1.0).toDouble()),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Foglio con le regole del gioco.
void showRules(BuildContext context, String title, String text) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1E3C),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Regole · $title', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Text(text, style: const TextStyle(height: 1.45, color: Colors.white70)),
      ]),
    ),
  );
}
