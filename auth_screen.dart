import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../audio.dart';
import '../avatars.dart';
import '../supa.dart';
import '../theme.dart';
import '../widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _user = TextEditingController();
  bool _signup = false, _busy = false, _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _user.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty || _pass.text.isEmpty) {
      toast(context, 'Inserisci email e password.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      if (_signup) {
        final nick = _user.text.trim();
        if (!nickRegex.hasMatch(nick)) {
          toast(context, errText('username_invalid'), error: true);
          return;
        }
        final free = await supa.rpc('check_username', params: {'p_username': nick});
        if (free != true) {
          toast(context, errText('username_taken'), error: true);
          return;
        }
        final res = await supa.auth.signUp(email: email, password: _pass.text, data: {'username': nick});
        if (res.session == null && mounted) {
          toast(context, 'Account creato. Conferma la mail oppure disattiva "Confirm email" in Supabase.');
        } else {
          Sfx.i.play('start');
        }
      } else {
        await supa.auth.signInWithPassword(email: email, password: _pass.text);
        Sfx.i.play('start');
      }
    } on AuthException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Connessione instabile o nick già in uso. Riprova.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      toast(context, 'Scrivi prima la tua email.', error: true);
      return;
    }
    try {
      await supa.auth.resetPasswordForEmail(email);
      if (mounted) toast(context, 'Se l\'email esiste, riceverai il link per reimpostare la password.');
    } on AuthException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Connessione instabile, riprova.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Pal.violet, Pal.cyan], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    boxShadow: [BoxShadow(color: Color(0x667C4DFF), blurRadius: 30)],
                  ),
                  child: const Text('⚔️', style: TextStyle(fontSize: 48)),
                ),
                const SizedBox(height: 16),
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(colors: [Colors.white, Pal.cyan]).createShader(r),
                  child: const Text('DuelApp', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
                const Text('Sfide 1 contro 1 · Gemme virtuali di test', style: TextStyle(color: Colors.white60)),
                const SizedBox(height: 26),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    if (_signup) ...[
                      TextField(
                        controller: _user,
                        decoration: const InputDecoration(labelText: 'Nick (3-20: lettere, numeri, _)', prefixIcon: Icon(Icons.badge_outlined)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      obscureText: _hide,
                      onSubmitted: (_) => _busy ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : Text(_signup ? 'Registrati' : 'Accedi'),
                      ),
                    ),
                    if (!_signup) TextButton(onPressed: _reset, child: const Text('Password dimenticata?')),
                  ]),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _signup = !_signup),
                  child: Text(_signup ? 'Ho già un account' : 'Crea un account'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
