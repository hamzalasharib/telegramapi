import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// NOVA visual identity: deep-space gradient, neon violet→cyan accent,
/// glass surfaces, 20px radii. Original design, not a Spotify clone.
class ThemePreset {
  final String name;
  final Color accent;
  final Color darkBg;
  const ThemePreset(this.name, this.accent, this.darkBg);
}

class NovaTheme {

  /// Full theme presets (accent + matching dark background tint).
  static const presets = <ThemePreset>[
    ThemePreset('Emerald Pulse', Color(0xFF1ED760), Color(0xFF0A120C)),
    ThemePreset('Nova Violet', Color(0xFF7C3AED), Color(0xFF0B0B14)),
    ThemePreset('Ocean Cyan', Color(0xFF00C2FF), Color(0xFF071018)),
    ThemePreset('Rose Beat', Color(0xFFFF3D71), Color(0xFF140A10)),
    ThemePreset('Mint Fresh', Color(0xFF00D68F), Color(0xFF081410)),
    ThemePreset('Golden Hour', Color(0xFFFFAA00), Color(0xFF141007)),
    ThemePreset('Sunset', Color(0xFFFF6B35), Color(0xFF140D08)),
    ThemePreset('Royal Blue', Color(0xFF4F7CFF), Color(0xFF090E1A)),
    ThemePreset('Magenta Pop', Color(0xFFE93FD8), Color(0xFF130A14)),
    ThemePreset('Crimson', Color(0xFFE5322D), Color(0xFF140808)),
  ];

  /// Accent palette for the custom color picker.
  static const accents = <Color>[
    Color(0xFF1ED760), Color(0xFF7C3AED), Color(0xFF00C2FF), Color(0xFFFF3D71),
    Color(0xFF00D68F), Color(0xFFFFAA00), Color(0xFFFF6B35), Color(0xFF4F7CFF),
    Color(0xFFE93FD8), Color(0xFFE5322D), Color(0xFF00B8A9), Color(0xFFFFD93D),
    Color(0xFF6C5CE7), Color(0xFF00A8E8), Color(0xFFFF7BAC), Color(0xFF95E1D3),
    Color(0xFFF38181), Color(0xFFAA96DA), Color(0xFFFCBAD3), Color(0xFFA8E6CF),
    Color(0xFF3DC1D3), Color(0xFFE15F41), Color(0xFF786FA6), Color(0xFFF8A5C2),
  ];

  static ThemeData build({
    required Brightness brightness,
    required Color accent,
    required bool amoled,
    Color? darkBg,
  }) {
    final dark = brightness == Brightness.dark;
    final bg = amoled && dark ? Colors.black : (dark ? (darkBg ?? const Color(0xFF0B0B14)) : const Color(0xFFF4F4FA));
    final surface = amoled && dark
        ? const Color(0xFF0A0A0A)
        : (dark ? Color.alphaBlend(Colors.white.withOpacity(.055), bg) : Colors.white);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      surface: surface,
      onSurface: dark ? Colors.white : const Color(0xFF14141F),
    );
    final navBg = dark ? const Color(0xFF10101D) : Colors.white;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Roboto',
      // Status bar + toolbar use the SAME background as the page so they
      // never clash (v1 had a transparent AppBar over a gradient page).
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: scheme.onSurface,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: bg,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: navBg,
          systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: .3,
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBg,
        elevation: 0,
        indicatorColor: accent.withOpacity(.22),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurface)),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? accent : scheme.onSurface.withOpacity(.65),
            size: 24)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent, thumbColor: accent,
        inactiveTrackColor: accent.withOpacity(.25),
        trackHeight: 3.5, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        side: BorderSide.none,
      ),
      snackBarTheme: SnackBarBehavior.floating ==
              SnackBarBehavior.floating
          ? SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))
          : null,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  static BoxDecoration pageGradient(BuildContext c) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    final accent = Theme.of(c).colorScheme.primary;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: dark
            ? [accent.withOpacity(.20), const Color(0xFF0B0B14), const Color(0xFF07070F)]
            : [accent.withOpacity(.14), const Color(0xFFF4F4FA), const Color(0xFFECECF6)],
        stops: const [0, .45, 1],
      ),
    );
  }

  static BoxDecoration glass(BuildContext c, {double radius = 20}) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    return BoxDecoration(
      color: dark ? Colors.white.withOpacity(.06) : Colors.white.withOpacity(.65),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: dark ? Colors.white.withOpacity(.09) : Colors.black.withOpacity(.05)),
    );
  }
}
