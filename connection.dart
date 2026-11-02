import 'dart:async';
import 'package:flutter/material.dart';
import 'supa.dart';
import 'theme.dart';

/// Controlla ogni pochi secondi che il server risponda; la UI mostra un banner quando cade.
class ConnectionMonitor {
  ConnectionMonitor._();
  static final ConnectionMonitor i = ConnectionMonitor._();

  final ValueNotifier<bool> online = ValueNotifier<bool>(true);
  Timer? _timer;
  bool _checking = false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => check());
    check();
  }

  void stop() => _timer?.cancel();

  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    try {
      await supa.from('games').select('id').limit(1).timeout(const Duration(seconds: 5));
      online.value = true;
    } catch (_) {
      online.value = false;
    } finally {
      _checking = false;
    }
  }
}

/// Banner in alto: "Connessione persa" finché il server non torna raggiungibile.
class ConnectionBanner extends StatelessWidget {
  final Widget child;
  const ConnectionBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: child),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: ValueListenableBuilder<bool>(
          valueListenable: ConnectionMonitor.i.online,
          builder: (_, ok, __) => AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            offset: ok ? const Offset(0, -1.2) : Offset.zero,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Pal.red.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Connessione persa: riprovo in automatico…',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    TextButton(
                      onPressed: ConnectionMonitor.i.check,
                      child: const Text('Riprova', style: TextStyle(color: Colors.white)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Stream realtime che si riconnette da solo se cade (attesa 2 s tra un tentativo e l'altro).
Stream<Rows> resilient(Stream<Rows> Function() make) async* {
  while (true) {
    try {
      await for (final r in make()) {
        yield r;
      }
    } catch (_) {
      // cade e riprova
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
}
