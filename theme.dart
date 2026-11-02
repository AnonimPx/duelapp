import 'package:flutter/material.dart';

/// Palette e stile condiviso: tema scuro "arcade" viola/ciano con accenti oro.
class Pal {
  static const bg1 = Color(0xFF0A0E1F);
  static const bg2 = Color(0xFF1B1245);
  static const violet = Color(0xFF7C4DFF);
  static const cyan = Color(0xFF22D3EE);
  static const gold = Color(0xFFFFC857);
  static const pink = Color(0xFFFF4F8B);
  static const green = Color(0xFF3DDC97);
  static const red = Color(0xFFFF5C5C);
  static const card = Color(0x14FFFFFF); // bianco 8%
  static const border = Color(0x1FFFFFFF); // bianco 12%
}

ThemeData buildTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: Pal.violet,
    brightness: Brightness.dark,
    primary: Pal.violet,
    secondary: Pal.cyan,
    surface: const Color(0xFF14172B),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white10,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Pal.cyan, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Pal.violet,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Pal.border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xCC0A0E1F),
      indicatorColor: Pal.violet.withValues(alpha: 0.35),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF2A2F55),
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      actionTextColor: Pal.cyan,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// Sfondo a gradiente con aloni colorati, usato dietro ogni schermata.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Pal.bg2, Pal.bg1]),
      ),
      child: Stack(children: [
        Positioned(
          top: -120,
          right: -80,
          child: _glow(Pal.violet.withValues(alpha: 0.28), 320),
        ),
        Positioned(
          bottom: -140,
          left: -100,
          child: _glow(Pal.cyan.withValues(alpha: 0.14), 340),
        ),
        Positioned.fill(child: child),
      ]),
    );
  }

  static Widget _glow(Color c, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, Colors.transparent])),
        ),
      );
}

/// Card "vetro" semitrasparente.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? tint;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin, this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? Pal.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Pal.border),
      ),
      child: child,
    );
  }
}

/// Pillola con le Gemme.
class GemChip extends StatelessWidget {
  final Object value;
  final bool big;
  const GemChip(this.value, {super.key, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 14 : 10, vertical: big ? 8 : 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0x33FFC857), Color(0x1AFFC857)]),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Pal.gold.withValues(alpha: 0.5)),
      ),
      child: Text('💎 $value', style: TextStyle(fontWeight: FontWeight.w800, fontSize: big ? 18 : 13, color: Pal.gold)),
    );
  }
}

/// Icona e colore per ogni gioco (slug).
({IconData icon, Color color}) gameStyle(String? slug) {
  switch (slug) {
    case 'forza4':
      return (icon: Icons.blur_circular, color: Pal.cyan);
    case 'tris_pro':
      return (icon: Icons.tag, color: Pal.pink);
    case 'othello':
      return (icon: Icons.circle_outlined, color: Pal.green);
    case 'mulino':
      return (icon: Icons.hub_outlined, color: Pal.gold);
    case 'domino':
      return (icon: Icons.view_module_outlined, color: Pal.cyan);
    case 'scopa':
      return (icon: Icons.style_outlined, color: Pal.pink);
    case 'backgammon':
      return (icon: Icons.grid_view_rounded, color: Pal.gold);
    case 'scala40':
      return (icon: Icons.style_rounded, color: Pal.pink);
    case 'scacchi':
      return (icon: Icons.castle, color: Pal.gold);
    default:
      return (icon: Icons.grid_view_rounded, color: Pal.violet);
  }
}
