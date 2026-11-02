import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'audio.dart';
import 'connection.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'supa.dart';
import 'theme.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _anon = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_url.isEmpty || _anon.isEmpty) {
    runApp(const _MissingConfig());
    return;
  }
  await Supabase.initialize(url: _url, anonKey: _anon);
  await Sfx.i.init();
  ConnectionMonitor.i.start();
  runApp(const DuelApp());
}

class DuelApp extends StatelessWidget {
  const DuelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DuelApp',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => ConnectionBanner(child: child ?? const SizedBox.shrink()),
      home: StreamBuilder<AuthState>(
        stream: supa.auth.onAuthStateChange,
        builder: (context, _) => supa.auth.currentSession == null ? const AuthScreen() : const HomeScreen(),
      ),
    );
  }
}

/// Mostrata se l'app parte senza --dart-define (errore tipico del primo avvio).
class _MissingConfig extends StatelessWidget {
  const _MissingConfig();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'Configurazione mancante.\n\nAvvia con:\nflutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
