import 'package:flutter/material.dart';

/// Lyrics effects engine. v2.8–v2.32 shipped 240 presets
/// (24 bases × 10 colourways) — the user's verdict: "saare ke
/// saare same hain" (the colour clones of each base all felt
/// identical). v2.33 CLEANUP: a curated set of 40 presets —
/// every base once in its best form, six colour specials where
/// the colour IS the effect, and ten NEW mechanics (outline
/// letters, focus-pull, rise-in, pill sweep, pulse glow).
/// Consumed by SyncedLyricsView; previews live in
/// lyrics_effects.dart (_FxPreview).
///
/// Old saved indices (base * 10 + colourway, 0..239) are mapped
/// into the new list by [migrateIndex]; the store runs that
/// once under the 'fxPresetsV3' flag.
class LyricsFx {
  final int base;
  final int colourway;
  final String name;
  final String desc;
  final double blur; // inactive-line blur sigma (0 = sharp)
  final double idleOpacity; // upcoming lines
  final double pastOpacity; // already-sung lines
  final double scale; // active-line scale target
  final bool bounce; // easeOutBack pop curve
  final double sizeBoost; // active-line font size boost (px)
  final double idleScale; // inactive font-size factor (Giant uses <1)
  final double glow; // active-line glow shadow radius (0 = none)
  final bool gradient; // active line rendered as a colour gradient
  final bool pill; // active line sits on a tinted pill
  final bool wave; // inactive lines offset in a gentle wave
  final bool slide; // active line slides in
  final bool wordKaraoke; // words light up one by one with progress
  final bool typewriter; // characters reveal with progress
  final bool center; // centre-aligned layout
  final double letterSpacing;
  // v2.33 mechanics
  final bool outline; // active line as hollow outline letters
  final bool sweep; // pill background fills with line progress
  final bool pulse; // glow breathes across the line's duration
  final bool focusIn; // active line starts blurred, snaps sharp
  final bool rise; // lines rise into place when they turn active

  const LyricsFx({
    required this.base,
    required this.colourway,
    required this.name,
    required this.desc,
    this.blur = 0,
    this.idleOpacity = .55,
    this.pastOpacity = .32,
    this.scale = 1.05,
    this.bounce = false,
    this.sizeBoost = 2,
    this.idleScale = 1,
    this.glow = 0,
    this.gradient = false,
    this.pill = false,
    this.wave = false,
    this.slide = false,
    this.wordKaraoke = false,
    this.typewriter = false,
    this.center = false,
    this.letterSpacing = 0,
    this.outline = false,
    this.sweep = false,
    this.pulse = false,
    this.focusIn = false,
    this.rise = false,
  });

  /// The two colours of this colourway: [primary, secondary].
  /// Colourway 0 is the live theme accent (passed in); the rest
  /// are fixed pairs. Used for the active line, glow, pill and
  /// gradient.
  (Color, Color) colors(Color accent) {
    switch (colourway) {
      case 1: // Pearl (white / silver)
        return (Colors.white, const Color(0xFFB8C4CE));
      case 2: // Emerald
        return (const Color(0xFF1ED760), const Color(0xFF0E9F5A));
      case 3: // Cyan Sky
        return (const Color(0xFF00C2FF), const Color(0xFF0090FF));
      case 4: // Hot Pink
        return (const Color(0xFFFF3D71), const Color(0xFFFF7AB6));
      case 5: // Violet
        return (const Color(0xFFA259FF), const Color(0xFF6E56CF));
      case 6: // Gold
        return (const Color(0xFFFFC542), const Color(0xFFFF8A3D));
      case 7: // Sunset
        return (const Color(0xFFFF7A18), const Color(0xFFFF3D68));
      case 8: // Ice
        return (const Color(0xFF9BE7FF), const Color(0xFFD6F6FF));
      case 9: // Rose
        return (const Color(0xFFFF5C8A), const Color(0xFFFF9EBB));
      default: // 0 Theme
        return (accent, Color.lerp(accent, Colors.white, .35)!);
    }
  }

  static const colourwayNames = [
    'Theme', 'Pearl', 'Emerald', 'Cyan Sky', 'Hot Pink',
    'Violet', 'Gold', 'Sunset', 'Ice', 'Rose',
  ];

  static LyricsFx _p(int base, int cw, String name, String desc,
          {double blur = 0,
          double idleOpacity = .55,
          double pastOpacity = .32,
          double scale = 1.05,
          bool bounce = false,
          double sizeBoost = 2,
          double idleScale = 1,
          double glow = 0,
          bool gradient = false,
          bool pill = false,
          bool wave = false,
          bool slide = false,
          bool wordKaraoke = false,
          bool typewriter = false,
          bool center = false,
          double letterSpacing = 0,
          bool outline = false,
          bool sweep = false,
          bool pulse = false,
          bool focusIn = false,
          bool rise = false}) =>
      LyricsFx(
        base: base, colourway: cw, name: name, desc: desc,
        blur: blur, idleOpacity: idleOpacity, pastOpacity: pastOpacity,
        scale: scale, bounce: bounce, sizeBoost: sizeBoost,
        idleScale: idleScale, glow: glow, gradient: gradient,
        pill: pill, wave: wave, slide: slide, wordKaraoke: wordKaraoke,
        typewriter: typewriter, center: center,
        letterSpacing: letterSpacing, outline: outline, sweep: sweep,
        pulse: pulse, focusIn: focusIn, rise: rise,
      );

  /// The curated catalogue (v2.33): 24 signature effects, 6
  /// colour specials, 10 new-mechanic effects. Index-stable from
  /// now on — append, never reorder.
  static final List<LyricsFx> presets = [
    _p(2, 0, 'Classic', 'Simple bold current line — clean and calm',
        sizeBoost: 0, scale: 1.0, idleOpacity: .62, pastOpacity: .38),
    _p(0, 0, 'Karaoke Words', 'Words light up one by one as the line is sung',
        wordKaraoke: true, sizeBoost: 2.5, idleOpacity: .58),
    _p(3, 0, 'Blur Focus', 'Only the current line is clear — the rest stays blurred',
        blur: 2.2, sizeBoost: 2.5, idleOpacity: .45, pastOpacity: .45),
    _p(1, 0, 'Glow', 'The current line glows bright',
        glow: 22, idleOpacity: .48, pastOpacity: .30),
    _p(4, 0, 'Pop Zoom', 'The current line pops in with a zoom bounce',
        sizeBoost: 3, scale: 1.13, bounce: true),
    _p(7, 0, 'Pill Highlight', 'The current line sits on a coloured pill',
        pill: true, sizeBoost: 1.5, scale: 1.02, pastOpacity: .34),
    _p(8, 0, 'Giant Center', 'Huge centred current line, small lines around it',
        center: true, sizeBoost: 5, scale: 1.06, idleScale: .8,
        idleOpacity: .45, pastOpacity: .28),
    _p(10, 0, 'Typewriter', 'Letters appear one by one, like being typed live',
        typewriter: true, idleOpacity: .52),
    _p(11, 0, 'Neon Sign', 'Neon-glow gradient letters, club-sign style',
        glow: 30, gradient: true, letterSpacing: .6, sizeBoost: 2.5,
        idleOpacity: .42, pastOpacity: .26),
    _p(6, 0, 'Wave Flow', 'Lines rest in a gentle wave, the current one straightens',
        wave: true, pastOpacity: .34),
    _p(5, 0, 'Slide Fade', 'Lines slide and fade as they change',
        slide: true, sizeBoost: 1.5, scale: 1.03,
        idleOpacity: .50, pastOpacity: .30),
    _p(9, 0, 'Dream Blur', 'Extra-deep dreamy blur — only the sung line exists',
        blur: 4.6, sizeBoost: 3, scale: 1.06, glow: 10,
        idleOpacity: .38, pastOpacity: .38),
    _p(12, 0, 'Cinema Center', 'Huge centred line over a soft blur, film-subtitle style',
        center: true, blur: 1.6, sizeBoost: 4, idleScale: .85,
        idleOpacity: .5, pastOpacity: .5),
    _p(13, 0, 'Spotlight Pill', 'A glowing pill picks the line out of the dark',
        pill: true, glow: 16, scale: 1.04, idleOpacity: .5, pastOpacity: .3),
    _p(15, 0, 'Karaoke Glow', 'Words light up inside a bright glow',
        wordKaraoke: true, glow: 18, sizeBoost: 2.5,
        idleOpacity: .55, pastOpacity: .3),
    _p(16, 0, 'Bounce Pill', 'The pill pops with every new line',
        pill: true, bounce: true, scale: 1.12, idleOpacity: .55),
    _p(17, 0, 'Mono Type', 'Typewriter in wide mono spacing',
        typewriter: true, letterSpacing: 1.4, sizeBoost: 1.5,
        scale: 1.03, idleOpacity: .5, pastOpacity: .3),
    _p(18, 0, 'Grand Stage', 'Theatre-size centre line, tiny chorus around it',
        center: true, glow: 12, sizeBoost: 6, idleScale: .72,
        scale: 1.07, idleOpacity: .42, pastOpacity: .26),
    _p(19, 0, 'Soft Focus', 'Gentle blur that keeps sung lines visible',
        blur: 3.2, scale: 1.04, idleOpacity: .5, pastOpacity: .52),
    _p(14, 0, 'Echo Wave', 'Wavy lines with a dreamy echo blur',
        wave: true, blur: 1.2, glow: 8, idleOpacity: .52, pastOpacity: .4),
    _p(20, 0, 'Slide Pill', 'Lines slide in on a coloured pill',
        slide: true, pill: true, sizeBoost: 1.5, scale: 1.03,
        idleOpacity: .52, pastOpacity: .3),
    _p(21, 0, 'Neon Wave', 'Neon gradient letters riding the wave',
        wave: true, gradient: true, glow: 14, letterSpacing: .4,
        sizeBoost: 2.5, idleOpacity: .5, pastOpacity: .3),
    _p(22, 0, 'Whisper', 'Calm and minimal — no zoom, wide letter spacing',
        sizeBoost: 0, scale: 1.0, letterSpacing: .9,
        idleOpacity: .68, pastOpacity: .45),
    _p(23, 0, 'Karaoke Giant', 'Word-by-word karaoke, centre stage and huge',
        wordKaraoke: true, center: true, sizeBoost: 4, idleScale: .8,
        scale: 1.06, idleOpacity: .5, pastOpacity: .3),
    // Colour specials — here the colour is the whole point.
    _p(11, 2, 'Neon Emerald', 'Neon sign in emerald green',
        glow: 30, gradient: true, letterSpacing: .6, sizeBoost: 2.5,
        idleOpacity: .42, pastOpacity: .26),
    _p(11, 4, 'Neon Pink', 'Neon sign in hot pink',
        glow: 30, gradient: true, letterSpacing: .6, sizeBoost: 2.5,
        idleOpacity: .42, pastOpacity: .26),
    _p(1, 6, 'Golden Glow', 'A warm golden glow on the singing line',
        glow: 22, idleOpacity: .48, pastOpacity: .30),
    _p(2, 1, 'Pearl', 'Pure white and silver — the minimal classic',
        sizeBoost: 0, scale: 1.0, idleOpacity: .62, pastOpacity: .38),
    _p(3, 8, 'Ice Focus', 'Blur focus in cold ice blue',
        blur: 2.2, sizeBoost: 2.5, idleOpacity: .45, pastOpacity: .45),
    _p(6, 7, 'Sunset Flow', 'Wave flow in a sunset gradient',
        wave: true, gradient: true, sizeBoost: 2.5, pastOpacity: .34),
    // New mechanics (v2.33).
    _p(2, 0, 'Outline', 'Hollow outline letters — nothing else like it',
        outline: true, sizeBoost: 1.5, scale: 1.04,
        idleOpacity: .5, pastOpacity: .3),
    _p(11, 0, 'Outline Glow', 'Outline letters with a neon halo',
        outline: true, glow: 16, letterSpacing: .5, sizeBoost: 2,
        scale: 1.05, idleOpacity: .45, pastOpacity: .28),
    _p(3, 0, 'Focus Pull', 'Each line starts soft and snaps into focus as it is sung',
        focusIn: true, blur: 1.3, sizeBoost: 2.5,
        idleOpacity: .48, pastOpacity: .42),
    _p(5, 0, 'Rise', 'Lines rise up into place when their turn comes',
        rise: true, sizeBoost: 2, idleOpacity: .52, pastOpacity: .3),
    _p(7, 0, 'Sweep Pill', 'The pill fills up as the line is sung',
        pill: true, sweep: true, sizeBoost: 1.5, scale: 1.03,
        pastOpacity: .34),
    _p(1, 0, 'Pulse Glow', 'The glow breathes in and out across the line',
        glow: 26, pulse: true, sizeBoost: 2.5,
        idleOpacity: .48, pastOpacity: .3),
    _p(0, 0, 'Karaoke Sweep', 'Words light up on a pill that fills with the line',
        wordKaraoke: true, pill: true, sweep: true, sizeBoost: 2,
        scale: 1.04, idleOpacity: .55),
    _p(8, 0, 'Focus Stage', 'Giant centre line that pulls into focus',
        center: true, focusIn: true, sizeBoost: 5, idleScale: .8,
        scale: 1.06, idleOpacity: .45, pastOpacity: .28),
    _p(0, 0, 'Rise Karaoke', 'Karaoke words on lines that rise into place',
        wordKaraoke: true, rise: true, sizeBoost: 2.5,
        idleOpacity: .55),
    _p(6, 0, 'Outline Wave', 'Outline letters riding the wave',
        outline: true, wave: true, sizeBoost: 2, idleOpacity: .5,
        pastOpacity: .3),
  ];

  /// Legacy key (base * 10 + colourway) → new index, for the
  /// presets whose (base, colourway) pair survived the cleanup
  /// (the first 30 entries). Later new-mechanic entries share
  /// pairs with signature ones and are NOT migration targets.
  static final Map<int, int> _legacyMap = {
    for (var i = 0; i < 30; i++)
      presets[i].base * 10 + presets[i].colourway: i,
  };

  /// Map a pre-v2.33 preset index (0..239, base*10+colourway)
  /// into the curated list. Exact pair wins; otherwise the
  /// base's Theme-colour entry; otherwise Classic (0).
  static int migrateIndex(int old) {
    final exact = _legacyMap[old];
    if (exact != null) return exact;
    final baseOnly = _legacyMap[(old ~/ 10) * 10];
    if (baseOnly != null) return baseOnly;
    return 0;
  }

  static LyricsFx of(int index) =>
      presets[index.clamp(0, presets.length - 1)];
}
