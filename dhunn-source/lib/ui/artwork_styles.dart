import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/models.dart';

/// Album-art styles for the Now Playing hero (v2.15 — his request:
/// "disc aur Spotify wale jaise buhut zyada styles"). The index is
/// AppStore.playerStyle. Every style fits inside a size×size box.
const artStyleNames = <String>[
  'Vinyl Disc',
  'Spotify Card',
  'Cinematic Wide',
  'CD Circle',
  'Sleeve & Disc',
  'Polaroid',
  'Glass Frame',
  'Poster Tall',
  'Tilt 3D',
  'Cassette',
  'Minimal',
  'Neon Ring',
  'Half Disc',
  'Gradient Border',
  'Retro Sunset',
  'EQ Ring',
  'Tape Deck Wide',
  'Vinyl Half Moon',
  'Neon Square',
  'Chrome Ring',
  'Sunset Disc',
  'Mono Frame',
  'Diamond Cut',
  'Circle Wave',
  'Retro TV',
  'Vinyl Label',
  'Glow Square',
  'Double Ring',
  'Tape Mini',
  'Poster Glow',
  'Glass Disc',
  'Rainbow Edge',
  'Night Drive',
  'Paper Sleeve',
  'Holo Ring',
  'Studio Monitor',
  'Vinyl Gold',
  'Cloud Frame',
  'Pixel Frame',
  'Orbit Rings',
  'Crimson Disc',
  'Aqua Glass',
  'Star Badge',
  'Wave Border',
  'Disc Duo',
  'Spotlight',
  'Vinyl Stack',
  'Aurora Frame',
  'Classic 45',
  'Glow Cassette',
  'Prism Square',
  'Midnight Vinyl',
  'Gallery Frame',
  'Vinyl Deluxe',
  'Magazine Cover',
  'Cinema Pro',
  'Studio Sleeve',
  'Gallery Card',
];

const artStyleSubs = <String>[
  'Spinning record with a glowing ring',
  'The classic square card, Spotify-style',
  'Wide cinematic crop with a colour glow',
  'Shiny compact disc, standing still',
  'Cover sleeve with the disc sliding out',
  'Retro photo print, slightly tilted',
  'Frosted glass frame around the art',
  'Tall portrait poster crop',
  'Floating card with a 3D tilt',
  'Retro tape with spinning reels',
  'Small, clean and centred',
  'Glowing neon ring around a round cover',
  'Cover card with a vinyl sliding out sideways',
  'Square cover in a glowing gradient frame',
  'Warm sunset stripes over the cover',
  'Round cover ringed by equalizer bars',
  'Wide tape deck with a big art window',
  'Spinning disc rising over a colour panel',
  'Square cover in a glowing neon frame',
  'Round cover in a shiny chrome ring',
  'Warm sunset wash over a spinning disc',
  'Gallery-style thick white frame',
  'Cover in a tilted diamond frame',
  'Round cover with a waveform under it',
  'Old television frame with antennas',
  'Tiny label art on a big black disc',
  'Square cover with a strong colour glow',
  'Round cover with two bright rings',
  'Pocket cassette with a photo window',
  'Tall poster with a glow behind it',
  'Frosted glass disc, iPhone style',
  'Rainbow gradient border, pride bright',
  'Wide night-drive crop with a light bar',
  'Cover slipped into a paper sleeve',
  'Holographic rainbow ring, spinning',
  'Studio monitor frame with speaker dots',
  'Golden disc with a gold label',
  'Soft cloud-white frame, dreamy shadow',
  'Retro 8-bit stepped pixel border',
  'Round cover with orbit rings around it',
  'Deep red disc, always crimson',
  'Aqua glass wash over a square cover',
  'Gold star badge on the corner',
  'Equalizer wave along the bottom edge',
  'Cover card with its disc beside it',
  'Small round cover under a spotlight',
  'A stack of three vinyl records',
  'Aurora gradient frame, northern lights',
  'Old 45 rpm record with the big hole',
  'Cassette glowing in your theme colour',
  'Prism light streak across the cover',
  'Near-black disc with a thin colour ring',
  'Museum matte frame with a fine gold keyline',
  'Premium pressing — fine grooves, gold label ring, metal spindle',
  'Editorial cover with a masthead and caption rules',
  'Letterbox widescreen with a clean accent line',
  'Record-store sleeve with an accent spine',
  'Artwork mounted on a gallery label card',
];

class ArtworkView extends StatefulWidget {
  final MediaItem item;
  final int style;
  final double size;
  final bool playing;
  final Color accent;
  final bool rotateDisc;
  const ArtworkView({
    super.key,
    required this.item,
    required this.style,
    required this.size,
    required this.playing,
    required this.accent,
    this.rotateDisc = true,
  });
  @override
  State<ArtworkView> createState() => _ArtworkViewState();
}

class _ArtworkViewState extends State<ArtworkView>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(seconds: 14));
  // Gentle 2.2 s pulse for the v2.28 design animations (glow,
  // breathe, sway). Runs ONLY while playing, like the spin.
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Widget _img() {
    final url = widget.item.artworkUrl;
    if (url != null && url.startsWith('http')) {
      return Image.network(url,
          fit: BoxFit.cover, cacheWidth: 720,
          errorBuilder: (_, __, ___) => _fallback());
    }
    if (url != null && url.startsWith('/')) {
      return Image.file(File(url),
          fit: BoxFit.cover, cacheWidth: 720,
          errorBuilder: (_, __, ___) => _fallback());
    }
    return _fallback();
  }

  Widget _fallback() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              widget.accent,
              Color.lerp(widget.accent, Colors.black, .4)!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
            child: Icon(Icons.music_note_rounded,
                size: 84, color: Colors.white70)),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.playing) {
      if (!_spin.isAnimating) _spin.repeat();
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _spin.stop();
      _pulse.stop();
    }
    final s = widget.size;
    final accent = widget.accent;
    switch (widget.style) {
      case 0:
        return _breathe(_disc(s, accent), from: .985, to: 1.012);
      case 2:
        return _glowPulse(_wide(s, accent), accent, r: 18);
      case 3:
        return _breathe(_cd(s, accent));
      case 4:
        return _sway(_sleeve(s, accent), amt: .012);
      case 5:
        return _sway(_polaroid(s));
      case 6:
        return _breathe(_glass(s));
      case 7:
        return _glowPulse(_poster(s, accent), accent, r: 14, blur: 30);
      case 8:
        return _sway(_tilt(s), amt: .018);
      case 9:
        return _breathe(_cassette(s), from: .985, to: 1.01);
      case 10:
        return _breathe(_minimal(s));
      case 11:
        return _breathe(_neonRing(s, accent), from: .985, to: 1.012);
      case 12:
        return _breathe(_halfDisc(s, accent), from: .985, to: 1.012);
      case 13:
        return _glowPulse(_gradientBorder(s, accent), accent, r: 20);
      case 14:
        return _breathe(_retroSunset(s, accent));
      case 15:
        return _eqRing(s, accent);
      case 16:
        return _breathe(_tapeWide(s, accent), from: .99, to: 1.008);
      case 17:
        return _breathe(_halfMoon(s, accent), from: .985, to: 1.012);
      case 18:
        return _glowPulse(_neonSquare(s, accent), accent, r: 24);
      case 19:
        return _breathe(_chromeRing(s));
      case 20:
        return _breathe(_sunsetDisc(s, accent), from: .985, to: 1.012);
      case 21:
        return _sway(_monoFrame(s), amt: .012);
      case 22:
        return _breathe(_diamond(s));
      case 23:
        return _circleWave(s, accent);
      case 24:
        return _breathe(_retroTv(s));
      case 25:
        return _breathe(_vinylLabel(s, accent));
      case 26:
        return _glowPulse(_glowSquare(s, accent), accent, r: 20, blur: 34);
      case 27:
        return _breathe(_doubleRing(s, accent));
      case 28:
        return _breathe(_tapeMini(s, accent));
      case 29:
        return _glowPulse(_posterGlow(s, accent), accent, r: 14, blur: 30);
      case 30:
        return _glassDisc(s);
      case 31:
        return _glowPulse(_rainbowEdge(s), const Color(0xFFA259FF), r: 24);
      case 32:
        return _breathe(_nightDrive(s, accent));
      case 33:
        return _sway(_paperSleeve(s));
      case 34:
        return _breathe(_holoRing(s), from: .985, to: 1.012);
      case 35:
        return _breathe(_studioMonitor(s, accent));
      case 36:
        return _breathe(_vinylGold(s), from: .985, to: 1.012);
      case 37:
        return _breathe(_cloudFrame(s));
      case 38:
        return _breathe(_pixelFrame(s, accent));
      case 39:
        return _orbitRings(s, accent);
      case 40:
        return _breathe(_crimsonDisc(s), from: .985, to: 1.012);
      case 41:
        return _breathe(_aquaGlass(s));
      case 42:
        return _starBadge(s);
      case 43:
        return _waveBorder(s, accent);
      case 44:
        return _breathe(_discDuo(s, accent));
      case 45:
        return _glowPulse(_spotlight(s, accent), accent, r: 24, blur: 30);
      case 46:
        return _breathe(_vinylStack(s, accent), from: .985, to: 1.012);
      case 47:
        return _glowPulse(_auroraFrame(s), const Color(0xFF7C3AED), r: 24);
      case 48:
        return _breathe(_classic45(s, accent), from: .985, to: 1.012);
      case 49:
        return _glowPulse(_glowCassette(s, accent), accent, r: 14);
      case 50:
        return _breathe(_prismSquare(s, accent));
      case 51:
        return _breathe(_midnightVinyl(s, accent), from: .985, to: 1.012);
      case 52:
        return _sway(_galleryFrame(s), amt: .008);
      case 53:
        return _breathe(_vinylDeluxe(s, accent), from: .985, to: 1.012);
      case 54:
        return _breathe(_magazineCover(s, accent));
      case 55:
        return _glowPulse(_cinemaPro(s, accent), accent, r: 6, blur: 22);
      case 56:
        return _sway(_studioSleeve(s, accent), amt: .01);
      case 57:
        return _breathe(_galleryCard(s, accent));
      case 1:
      default:
        return _breathe(_card(s), from: .975, to: 1.015);
    }
  }

  // v2.28 animation helpers. Lag rule: only transform, opacity
  // and shadow values move, and the artwork image is always
  // passed through as the CACHED child — it never repaints.
  double get _p => _pulse.value;

  Widget _breathe(Widget child, {double from = .98, double to = 1.015}) =>
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, c) =>
            Transform.scale(scale: from + (to - from) * _p, child: c),
        child: child,
      );

  Widget _sway(Widget child, {double amt = .02}) => AnimatedBuilder(
        animation: _pulse,
        builder: (_, c) =>
            Transform.rotate(angle: (_p - .5) * 2 * amt, child: c),
        child: child,
      );

  Widget _glowPulse(Widget child, Color color,
          {double r = 22, double blur = 26}) =>
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, c) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(.28 + .30 * _p),
                  blurRadius: blur + 12 * _p,
                  spreadRadius: 2)
            ],
          ),
          child: c,
        ),
        child: child,
      );

  Widget _ringOsc(double base, Widget child) => AnimatedBuilder(
        animation: _pulse,
        builder: (_, c) =>
            Transform.rotate(angle: base + (_p - .5) * .22, child: c),
        child: child,
      );

  Widget _rotating(Widget child) => AnimatedBuilder(
        animation: _spin,
        builder: (_, c) => Transform.rotate(
            angle: widget.rotateDisc ? _spin.value * 2 * pi : 0,
            child: c),
        child: child,
      );

  // 0 — Vinyl disc (the pre-v2.15 hero, kept exactly).
  Widget _disc(double s, Color accent) => SizedBox(
        width: s,
        height: s,
        child: Stack(alignment: Alignment.center, children: [
          _rotating(Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: accent.withOpacity(.5),
                    blurRadius: 46,
                    spreadRadius: 5)
              ],
            ),
            child: ClipOval(child: _img()),
          )),
          Container(
            width: s * .72,
            height: s * .72,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(.10), width: 10)),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10101C),
                border: Border.all(color: Colors.white24, width: 2)),
            child: Center(
                child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white70),
            )),
          ),
        ]),
      );

  // 1 — Spotify card (the pre-v2.15 card, kept exactly).
  Widget _card(double s) => AnimatedScale(
        scale: widget.playing ? 1.0 : 0.93,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(.5),
                    blurRadius: 34,
                    offset: const Offset(0, 14))
              ]),
          child:
              ClipRRect(borderRadius: BorderRadius.circular(14), child: _img()),
        ),
      );

  // 2 — Cinematic wide (the pre-v2.15 full art, kept exactly).
  Widget _wide(double s, Color accent) => Container(
        width: s,
        height: (s * .78).clamp(200.0, 340.0),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: accent.withOpacity(.4),
                  blurRadius: 36,
                  spreadRadius: 3)
            ]),
        child:
            ClipRRect(borderRadius: BorderRadius.circular(16), child: _img()),
      );

  // 3 — CD circle: silver-rimmed disc that does not spin.
  Widget _cd(double s, Color accent) => Container(
        width: s,
        height: s,
        padding: const EdgeInsets.all(7),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Color(0xFFE8E8EC),
              Color(0xFF9A9AA4),
              Color(0xFFF2F2F6),
              Color(0xFF7E7E88)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: Colors.black),
          padding: const EdgeInsets.all(3),
          child: Stack(alignment: Alignment.center, children: [
            ClipOval(child: SizedBox.expand(child: _img())),
            // sheen
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(.22),
                    Colors.transparent,
                    Colors.white.withOpacity(.10)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF14141C),
                  border: Border.all(color: Colors.white38, width: 2)),
              child: Center(
                  child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white60),
              )),
            ),
          ]),
        ),
      );

  // 4 — Sleeve with the disc sliding out to the right.
  Widget _sleeve(double s, Color accent) => SizedBox(
        width: s,
        height: s,
        child: Stack(children: [
          Align(
            alignment: Alignment.centerRight,
            child: _rotating(Container(
              width: s * .9,
              height: s * .9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF23232C), Color(0xFF0C0C12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                      color: accent.withOpacity(.35), blurRadius: 30)
                ],
              ),
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: s * .52,
                  height: s * .52,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(.14), width: 8)),
                ),
                ClipOval(
                  child: SizedBox(
                      width: s * .34, height: s * .34, child: _img()),
                ),
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0xFF10101C)),
                ),
              ]),
            )),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: s * .8,
              height: s * .8,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(.55),
                        blurRadius: 26,
                        offset: const Offset(0, 12))
                  ]),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(8), child: _img()),
            ),
          ),
        ]),
      );

  // 5 — Polaroid print.
  Widget _polaroid(double s) {
    final w = s * .88;
    return Transform.rotate(
      angle: -0.03,
      child: Container(
        width: w,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 34),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.5),
                blurRadius: 28,
                offset: const Offset(0, 14))
          ],
        ),
        child: AspectRatio(aspectRatio: 1, child: _img()),
      ),
    );
  }

  // 6 — Glass frame.
  Widget _glass(double s) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: s,
            height: s,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.13),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: Colors.white.withOpacity(.35), width: 1.2),
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(14), child: _img()),
          ),
        ),
      );

  // 7 — Tall poster.
  Widget _poster(double s, Color accent) => Container(
        width: s * .76,
        height: s,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: accent.withOpacity(.35),
                  blurRadius: 34,
                  offset: const Offset(0, 14))
            ]),
        child:
            ClipRRect(borderRadius: BorderRadius.circular(18), child: _img()),
      );

  // 8 — 3D tilt card.
  Widget _tilt(double s) => AnimatedScale(
        scale: widget.playing ? 1.0 : 0.94,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0016)
            ..rotateY(0.20)
            ..rotateX(-0.07),
          child: Container(
            width: s * .94,
            height: s * .94,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(.6),
                      blurRadius: 38,
                      offset: const Offset(20, 24))
                ]),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(14), child: _img()),
          ),
        ),
      );

  // 9 — Cassette with spinning reels.
  Widget _cassette(double s) {
    Widget reel() => AnimatedBuilder(
          animation: _spin,
          builder: (_, c) => Transform.rotate(
              angle: widget.playing ? _spin.value * 2 * pi : 0, child: c),
          child: Container(
            width: s * .17,
            height: s * .17,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(.14),
              border: Border.all(
                  color: Colors.white.withOpacity(.55), width: 2),
            ),
            child: CustomPaint(painter: _ReelPainter()),
          ),
        );
    return Container(
      width: s,
      height: s * .74,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF191922),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.14)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.5),
              blurRadius: 30,
              offset: const Offset(0, 12))
        ],
      ),
      child: Column(children: [
        Expanded(
          child: ClipRRect(
              borderRadius: BorderRadius.circular(9), child: _img()),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          reel(),
          Container(
              width: s * .3,
              height: 5,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.25),
                  borderRadius: BorderRadius.circular(3))),
          reel(),
        ]),
        const SizedBox(height: 4),
      ]),
    );
  }

  // 10 — Minimal.
  Widget _minimal(double s) => Container(
        width: s * .55,
        height: s * .55,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(.45),
                  blurRadius: 26,
                  offset: const Offset(0, 10))
            ]),
        child:
            ClipRRect(borderRadius: BorderRadius.circular(20), child: _img()),
      );

  // 11 — Neon Ring: round cover inside a glowing gradient ring,
  // with a rotating dashed arc on the outside.
  Widget _neonRing(double s, Color accent) => SizedBox(
        width: s, height: s,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            width: s, height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: accent.withOpacity(.55), blurRadius: 44, spreadRadius: 4)],
            ),
          ),
          _rotating(CustomPaint(
            size: Size(s, s),
            painter: _DashRingPainter(accent),
          )),
          Container(
            width: s * .9, height: s * .9,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [accent, Color.lerp(accent, Colors.white, .4)!, accent],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
              padding: const EdgeInsets.all(3),
              child: ClipOval(child: SizedBox.expand(child: _img())),
            ),
          ),
        ]),
      );

  // 12 — Half Disc: cover card with a vinyl sliding out to the right.
  Widget _halfDisc(double s, Color accent) => SizedBox(
        width: s, height: s * .8,
        child: Stack(children: [
          Positioned(
            right: 0, top: s * .06,
            child: _rotating(Container(
              width: s * .68, height: s * .68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF26262F), Color(0xFF0B0B11)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: accent.withOpacity(.35), blurRadius: 26)],
              ),
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: s * .4, height: s * .4,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(.13), width: 7)),
                ),
                ClipOval(child: SizedBox(width: s * .24, height: s * .24, child: _img())),
                Container(width: 13, height: 13,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10101C))),
              ]),
            )),
          ),
          Positioned(
            left: 0, top: 0,
            child: Container(
              width: s * .66, height: s * .8,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(.55), blurRadius: 26, offset: const Offset(0, 12))]),
              child: ClipRRect(borderRadius: BorderRadius.circular(14), child: _img()),
            ),
          ),
        ]),
      );

  // 13 — Gradient Border.
  Widget _gradientBorder(double s, Color accent) => Container(
        width: s, height: s,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [accent, Color.lerp(accent, Colors.black, .35)!, Color.lerp(accent, Colors.white, .3)!, accent],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: accent.withOpacity(.35), blurRadius: 30, offset: const Offset(0, 12))],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(15), child: _img()),
      );

  // 14 — Retro Sunset: warm stripes + sun over the cover.
  Widget _retroSunset(double s, Color accent) => Container(
        width: s, height: s,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.5), blurRadius: 30, offset: const Offset(0, 12))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(fit: StackFit.expand, children: [
            _img(),
            Positioned(
              right: s * .08, top: s * .07,
              child: Container(
                width: s * .2, height: s * .2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [const Color(0xFFFFD76A), Color.lerp(accent, const Color(0xFFFF7A59), .5)!],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF9E5E).withOpacity(.6), blurRadius: 22)],
                ),
              ),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0, height: s * .3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, const Color(0xFFFF7A59).withOpacity(.45), const Color(0xFFB83A6E).withOpacity(.65)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  for (var i = 0; i < 3; i++)
                    Container(height: 2.5, margin: EdgeInsets.only(bottom: s * .045),
                        color: Colors.white.withOpacity(.35)),
                ]),
              ),
            ),
          ]),
        ),
      );

  // 15 — EQ Ring: round cover ringed by equalizer bars.
  Widget _eqRing(double s, Color accent) => SizedBox(
        width: s, height: s,
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(
            animation: _spin,
            builder: (_, __) => CustomPaint(
                size: Size(s, s),
                painter: _EqRingPainter(accent, phase: _spin.value)),
          ),
          Container(
            width: s * .8, height: s * .8,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(.15), width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.45), blurRadius: 24)]),
            child: ClipOval(child: SizedBox.expand(child: _img())),
          ),
          Container(width: 24, height: 24,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF10101C),
                  border: Border.all(color: Colors.white24, width: 2))),
        ]),
      );

  // 16 — Tape Deck Wide: big art window over a tape strip.
  Widget _tapeWide(double s, Color accent) {
    Widget reel() => AnimatedBuilder(
          animation: _spin,
          builder: (_, c) => Transform.rotate(
              angle: widget.playing ? _spin.value * 2 * pi : 0, child: c),
          child: Container(
            width: s * .15, height: s * .15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(.13),
              border: Border.all(color: Colors.white.withOpacity(.5), width: 2),
            ),
            child: CustomPaint(painter: _ReelPainter()),
          ),
        );
    return Container(
      width: s, height: s * .86,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF181820),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.13)),
        boxShadow: [BoxShadow(color: accent.withOpacity(.25), blurRadius: 28, offset: const Offset(0, 12))],
      ),
      child: Column(children: [
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox.expand(child: _img()))),
        const SizedBox(height: 11),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          reel(),
          Container(width: s * .34, height: 5,
              decoration: BoxDecoration(color: Colors.white.withOpacity(.22), borderRadius: BorderRadius.circular(3))),
          reel(),
        ]),
        const SizedBox(height: 3),
      ]),
    );
  }
  // ---- v2.27: 35 more designs (styles 17–51) ----

  Widget _sq(double s, {double r = 20, Widget? child}) =>
      SizedBox(width: s, height: s, child: child);

  // 17 — Vinyl Half Moon
  Widget _halfMoon(double s, Color accent) => _sq(s, child: Stack(
        alignment: Alignment.center,
        children: [
          _rotating(ClipOval(child: SizedBox(width: s, height: s, child: _img()))),
          Positioned(
            left: 0, right: 0, bottom: 0, height: s * .42,
            child: Container(
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(s / 2)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [accent.withOpacity(0), accent.withOpacity(.85)],
                ),
              ),
            ),
          ),
          Container(width: 22, height: 22,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: const Color(0xFF10101C),
                  border: Border.all(color: Colors.white38, width: 2))),
        ],
      ));

  // 18 — Neon Square
  Widget _neonSquare(double s, Color accent) => _sq(s, child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent, width: 3),
          boxShadow: [BoxShadow(color: accent.withOpacity(.55), blurRadius: 26, spreadRadius: 2)],
        ),
        padding: const EdgeInsets.all(5),
        child: ClipRRect(borderRadius: BorderRadius.circular(18), child: _img()),
      ));

  // 19 — Chrome Ring
  Widget _chromeRing(double s) => _sq(s, child: _rotating(Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: [
            Color(0xFF9AA5B1), Color(0xFFE8EEF4), Color(0xFF6E7A88),
            Color(0xFFF4F8FC), Color(0xFF9AA5B1),
          ]),
        ),
        padding: EdgeInsets.all(s * .045),
        child: AnimatedBuilder(
            animation: _spin,
            builder: (_, c) => Transform.rotate(
                angle: widget.rotateDisc ? -_spin.value * 2 * pi : 0,
                child: c),
            child: ClipOval(child: _img())),
      )));

  // 20 — Sunset Disc
  Widget _sunsetDisc(double s, Color accent) => _sq(s, child: Stack(
        alignment: Alignment.center,
        children: [
          _rotating(ClipOval(child: SizedBox(width: s, height: s, child: _img()))),
          Container(width: s, height: s,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [const Color(0xFFFF7A18).withOpacity(.30),
                               const Color(0xFFFF3D68).withOpacity(.30)]))),
          Container(width: s * .3, height: s * .3,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: const Color(0xFFFF8A3D),
                  border: Border.all(color: Colors.white30, width: 2))),
        ],
      ));

  // 21 — Mono Frame
  Widget _monoFrame(double s) => _sq(s, child: Container(
        decoration: BoxDecoration(color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.5), blurRadius: 24, offset: const Offset(0, 10))]),
        padding: EdgeInsets.all(s * .07),
        child: Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
            child: _img()),
      ));

  // 22 — Diamond Cut
  Widget _diamond(double s) => _sq(s, child: Center(
        child: Transform.rotate(
          angle: .785398,
          child: Container(
            width: s * .72, height: s * .72,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.45), blurRadius: 20)]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Transform.rotate(
                angle: -.785398,
                child: Transform.scale(scale: 1.45, child: _img()),
              ),
            ),
          ),
        ),
      ));

  // 23 — Circle Wave
  Widget _circleWave(double s, Color accent) => _sq(s, child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipOval(child: SizedBox(width: s * .76, height: s * .76, child: _img())),
          SizedBox(height: s * .05),
          AnimatedBuilder(
            animation: _spin,
            builder: (_, __) {
              const hs = [.35, .6, .9, .55, 1.0, .7, .45, .8, .5, .3];
              return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < hs.length; i++)
                      Container(
                          width: s * .045,
                          height: s * .13 * hs[i] *
                              (.45 + .55 * (sin(_spin.value * 4 * pi + i * .8) * .5 + .5)),
                          margin: EdgeInsets.symmetric(horizontal: s * .012),
                          decoration: BoxDecoration(
                              color: accent, borderRadius: BorderRadius.circular(4))),
                  ]);
            },
          ),
        ],
      ));

  // 24 — Retro TV
  Widget _retroTv(double s) => _sq(s, child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: s * .1, child: Stack(alignment: Alignment.bottomCenter, children: [
            Transform.rotate(angle: -.5, child: Container(width: 3, height: s * .11, color: Colors.white38)),
            Transform.rotate(angle: .5, child: Container(width: 3, height: s * .11, color: Colors.white38)),
          ])),
          Container(
            width: s * .94, height: s * .68,
            decoration: BoxDecoration(color: const Color(0xFF23232E),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12)),
            padding: EdgeInsets.all(s * .045),
            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: _img()),
          ),
          SizedBox(height: s * .04),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 3; i++)
              Container(width: 9, height: 9, margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: i == 0 ? Colors.redAccent : Colors.white24)),
          ]),
        ],
      ));

  // 25 — Vinyl Label
  Widget _vinylLabel(double s, Color accent) => _sq(s, child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF0C0C10),
            border: Border.all(color: Colors.white.withOpacity(.08), width: 8),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.5), blurRadius: 20)]),
        child: Center(child: _rotating(ClipOval(
            child: SizedBox(width: s * .42, height: s * .42, child: _img())))),
      ));

  // 26 — Glow Square
  Widget _glowSquare(double s, Color accent) => _sq(s, child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(.25)),
            boxShadow: [BoxShadow(color: accent.withOpacity(.65), blurRadius: 38, spreadRadius: 4)]),
        child: ClipRRect(borderRadius: BorderRadius.circular(20), child: _img()),
      ));

  // 27 — Double Ring
  Widget _doubleRing(double s, Color accent) => _sq(s, child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: s * .97, height: s * .97,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 3))),
          Container(width: s * .9, height: s * .9,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(.5), width: 2))),
          ClipOval(child: SizedBox(width: s * .82, height: s * .82, child: _img())),
        ],
      ));

  // 28 — Tape Mini
  Widget _tapeMini(double s, Color accent) => _sq(s, child: Center(
        child: Container(
          width: s * .94, height: s * .62,
          decoration: BoxDecoration(color: const Color(0xFF1A1A22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12)),
          padding: EdgeInsets.all(s * .05),
          child: Column(children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: _img())),
            SizedBox(height: s * .04),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _rotating(CustomPaint(size: const Size(26, 26), painter: _ReelPainter())),
              Container(width: s * .3, height: 5,
                  decoration: BoxDecoration(color: accent,
                      borderRadius: BorderRadius.circular(3))),
              _rotating(CustomPaint(size: const Size(26, 26), painter: _ReelPainter())),
            ]),
          ]),
        ),
      ));

  // 29 — Poster Glow
  Widget _posterGlow(double s, Color accent) => _sq(s, child: Center(
        child: Container(
          width: s * .72, height: s * .98,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: accent.withOpacity(.5), blurRadius: 34, spreadRadius: 2)]),
          child: ClipRRect(borderRadius: BorderRadius.circular(14),
              child: Stack(fit: StackFit.expand, children: [
                _img(),
                Container(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(.35)]))),
              ])),
        ),
      ));

  // 30 — Glass Disc
  Widget _glassDisc(double s) => _sq(s, child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(child: SizedBox(width: s, height: s, child: _img())),
          _rotating(Container(width: s, height: s,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(.35), width: 1.5),
                  gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.white.withOpacity(.22), Colors.white.withOpacity(.04)])))),
        ],
      ));

  // 31 — Rainbow Edge
  Widget _rainbowEdge(double s) => _sq(s, child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(colors: [
              Color(0xFFFF3D3D), Color(0xFFFFAA00), Color(0xFFFFD93D),
              Color(0xFF1ED760), Color(0xFF00C2FF), Color(0xFFA259FF),
            ])),
        padding: const EdgeInsets.all(4),
        child: ClipRRect(borderRadius: BorderRadius.circular(20), child: _img()),
      ));

  // 32 — Night Drive
  Widget _nightDrive(double s, Color accent) => _sq(s, child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: s, height: s * .6,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.5), blurRadius: 18)]),
            child: ClipRRect(borderRadius: BorderRadius.circular(16),
                child: Stack(fit: StackFit.expand, children: [
                  _img(),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(.55)]))),
                ])),
          ),
          SizedBox(height: s * .05),
          Container(width: s * .4, height: 4,
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: accent, blurRadius: 10)])),
        ],
      ));

  // 33 — Paper Sleeve
  Widget _paperSleeve(double s) => _sq(s, child: Transform.rotate(
        angle: -.03,
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFFEDE6DA),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.4), blurRadius: 18, offset: const Offset(0, 8))]),
          padding: EdgeInsets.all(s * .06),
          child: Column(children: [
            Expanded(child: _img()),
            SizedBox(height: s * .04),
            Container(height: 3, width: s * .5, color: Colors.black26),
          ]),
        ),
      ));

  // 34 — Holo Ring
  Widget _holoRing(double s) => _sq(s, child: Stack(
        alignment: Alignment.center,
        children: [
          _rotating(Container(width: s, height: s,
              decoration: const BoxDecoration(shape: BoxShape.circle,
                  gradient: SweepGradient(colors: [
                    Color(0xFFFF3D71), Color(0xFFFFC542), Color(0xFF1ED760),
                    Color(0xFF00C2FF), Color(0xFFA259FF), Color(0xFFFF3D71),
                  ])))),
          ClipOval(child: SizedBox(width: s * .84, height: s * .84, child: _img())),
        ],
      ));

  // 35 — Studio Monitor
  Widget _studioMonitor(double s, Color accent) => _sq(s, child: Container(
        decoration: BoxDecoration(color: const Color(0xFF14141C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10)),
        padding: EdgeInsets.all(s * .05),
        child: Column(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: _img())),
          SizedBox(height: s * .04),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 5; i++)
              Container(width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: i == 2 ? accent : Colors.white24)),
          ]),
        ]),
      ));

  // 36 — Vinyl Gold
  Widget _vinylGold(double s) => _sq(s, child: Stack(
        alignment: Alignment.center,
        children: [
          _rotating(Container(width: s, height: s,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFFFFC542).withOpacity(.5), blurRadius: 40, spreadRadius: 3)]),
              child: ClipOval(child: _img()))),
          Container(width: s * .34, height: s * .34,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFFFD93D), Color(0xFFFF8A3D)]),
                  border: Border.all(color: Colors.white38, width: 2))),
          Container(width: 12, height: 12,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10101C))),
        ],
      ));

  // 37 — Cloud Frame
  Widget _cloudFrame(double s) => _sq(s, child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(42),
            boxShadow: [BoxShadow(color: Colors.white.withOpacity(.22), blurRadius: 30),
                        BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 18, offset: const Offset(0, 8))]),
        padding: EdgeInsets.all(s * .05),
        child: ClipRRect(borderRadius: BorderRadius.circular(36), child: _img()),
      ));

  // 38 — Pixel Frame
  Widget _pixelFrame(double s, Color accent) => _sq(s, child: Stack(children: [
        Positioned(left: 10, top: 10, right: 0, bottom: 0,
            child: Container(decoration: BoxDecoration(border: Border.all(color: accent, width: 3)))),
        Positioned(left: 5, top: 5, right: 5, bottom: 5,
            child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 3)))),
        Positioned(left: 0, top: 0, right: 10, bottom: 10,
            child: Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3)),
                child: _img())),
      ]));

  // 39 — Orbit Rings
  Widget _orbitRings(double s, Color accent) => _sq(s, child: Stack(
        alignment: Alignment.center,
        children: [
          _ringOsc(.5, Container(width: s * .99, height: s * .52,
              decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.elliptical(s * .5, s * .26)),
                  border: Border.all(color: accent.withOpacity(.65), width: 2)))),
          _ringOsc(-.5, Container(width: s * .99, height: s * .52,
              decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.elliptical(s * .5, s * .26)),
                  border: Border.all(color: Colors.white.withOpacity(.35), width: 2)))),
          ClipOval(child: SizedBox(width: s * .68, height: s * .68, child: _img())),
        ],
      ));

  // 40 — Crimson Disc
  Widget _crimsonDisc(double s) => _sq(s, child: Stack(
        alignment: Alignment.center,
        children: [
          _rotating(Container(width: s, height: s,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFFE5322D).withOpacity(.55), blurRadius: 42, spreadRadius: 3)]),
              child: ClipOval(child: _img()))),
          Container(width: s * .32, height: s * .32,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE5322D),
                  border: Border.all(color: Colors.white30, width: 2))),
          Container(width: 12, height: 12,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10101C))),
        ],
      ));

  // 41 — Aqua Glass
  Widget _aquaGlass(double s) => _sq(s, child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF00C2FF).withOpacity(.5), width: 1.5)),
        child: ClipRRect(borderRadius: BorderRadius.circular(22),
            child: Stack(fit: StackFit.expand, children: [
              _img(),
              Container(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [const Color(0xFF00C2FF).withOpacity(.18),
                           const Color(0xFF9BE7FF).withOpacity(.05)]))),
            ])),
      ));

  // 42 — Star Badge
  Widget _starBadge(double s) => _sq(s, child: Stack(children: [
        Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: _img())),
        Positioned(right: 10, top: 10,
            child: _breathe(Container(width: 40, height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFFFFD93D), Color(0xFFFF8A3D)]),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.35), blurRadius: 8)]),
                child: const Icon(Icons.star, color: Colors.black87, size: 22)))),
      ]));

  // 43 — Wave Border
  Widget _waveBorder(double s, Color accent) => _sq(s, child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(fit: StackFit.expand, children: [
          _img(),
          Align(alignment: Alignment.bottomCenter,
              child: AnimatedBuilder(
                animation: _spin,
                builder: (_, __) {
                  const hs = [.3, .55, .85, .5, 1.0, .65, .4, .75, .45, .9, .55, .3];
                  return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < hs.length; i++)
                          Container(
                              width: s * .05,
                              height: s * .15 * hs[i] *
                                  (.45 + .55 * (sin(_spin.value * 4 * pi + i * .7) * .5 + .5)),
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                      colors: [accent, accent.withOpacity(.25)]),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))),
                      ]);
                },
              )),
        ]),
      ));

  // 44 — Disc Duo
  Widget _discDuo(double s, Color accent) => _sq(s, child: Stack(
        alignment: Alignment.center,
        children: [
          Align(alignment: Alignment.centerLeft,
              child: Container(width: s * .62, height: s * .62,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.4), blurRadius: 14)]),
                  child: ClipRRect(borderRadius: BorderRadius.circular(16), child: _img()))),
          Align(alignment: Alignment.centerRight,
              child: _rotating(Container(width: s * .56, height: s * .56,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF0C0C10),
                      border: Border.all(color: Colors.white.withOpacity(.12), width: 5)),
                  child: Center(child: ClipOval(
                      child: SizedBox(width: s * .24, height: s * .24, child: _img())))))),
        ],
      ));

  // 45 — Spotlight
  Widget _spotlight(double s, Color accent) => _sq(s, child: Container(
        decoration: BoxDecoration(color: Colors.black.withOpacity(.35),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10)),
        child: Stack(alignment: Alignment.center, children: [
          Container(width: s * .66, height: s * .66,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: accent.withOpacity(.5), blurRadius: 32)]),
              child: ClipOval(child: _img())),
          Container(width: s, height: s,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
                  gradient: RadialGradient(colors: [Colors.white.withOpacity(.14), Colors.transparent]))),
        ]),
      ));

  // 46 — Vinyl Stack
  Widget _vinylStack(double s, Color accent) => _sq(s, child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(offset: Offset(-s * .13, -s * .09),
              child: Container(width: s * .8, height: s * .8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF111116),
                      border: Border.all(color: Colors.white.withOpacity(.10), width: 6)))),
          Transform.translate(offset: Offset(s * .13, s * .08),
              child: Container(width: s * .8, height: s * .8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF17171F),
                      border: Border.all(color: Colors.white.withOpacity(.08), width: 6)))),
          _rotating(ClipOval(child: SizedBox(width: s * .78, height: s * .78, child: _img()))),
        ],
      ));

  // 47 — Aurora Frame
  Widget _auroraFrame(double s) => _sq(s, child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF00C2FF), Color(0xFF00D68F)]),
            boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(.4), blurRadius: 26)]),
        padding: const EdgeInsets.all(5),
        child: ClipRRect(borderRadius: BorderRadius.circular(19), child: _img()),
      ));

  // 48 — Classic 45
  Widget _classic45(double s, Color accent) => _sq(s, child: Stack(
        alignment: Alignment.center,
        children: [
          _rotating(ClipOval(child: SizedBox(width: s, height: s, child: _img()))),
          Container(width: s * .34, height: s * .34,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF10101C),
                  border: Border.all(color: Colors.white.withOpacity(.25), width: 3))),
          Container(width: 10, height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent)),
        ],
      ));

  // 49 — Glow Cassette
  Widget _glowCassette(double s, Color accent) => _sq(s, child: Center(
        child: Container(
          width: s * .94, height: s * .62,
          decoration: BoxDecoration(color: const Color(0xFF1A1A22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withOpacity(.6), width: 1.5),
              boxShadow: [BoxShadow(color: accent.withOpacity(.45), blurRadius: 28)]),
          padding: EdgeInsets.all(s * .05),
          child: Column(children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: _img())),
            SizedBox(height: s * .04),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _rotating(CustomPaint(size: const Size(26, 26), painter: _ReelPainter())),
              Text('DHUNN • 90', style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 2)),
              _rotating(CustomPaint(size: const Size(26, 26), painter: _ReelPainter())),
            ]),
          ]),
        ),
      ));

  // 50 — Prism Square
  Widget _prismSquare(double s, Color accent) => _sq(s, child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(.18))),
        child: ClipRRect(borderRadius: BorderRadius.circular(20),
            child: Stack(fit: StackFit.expand, children: [
              _img(),
              Container(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Colors.white.withOpacity(.14), Colors.transparent,
                           accent.withOpacity(.12)]))),
            ])),
      ));

  // 51 — Midnight Vinyl
  Widget _midnightVinyl(double s, Color accent) => _sq(s, child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: s, height: s,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF08080C),
                  border: Border.all(color: accent, width: 2))),
          _rotating(ClipOval(child: SizedBox(width: s * .88, height: s * .88, child: _img()))),
          Container(width: s * .55, height: s * .55,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(.06), width: 8))),
          Container(width: s * .3, height: s * .3,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Color.lerp(accent, Colors.black, .55),
                  border: Border.all(color: Colors.white24, width: 1.5))),
          Container(width: 10, height: 10,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white70)),
        ],
      ));

  // ---- v2.33: professional designs (styles 52–57) ----

  // 52 — Gallery Frame: museum matte with a fine gold keyline.
  Widget _galleryFrame(double s) => _sq(s, child: Container(
        decoration: BoxDecoration(color: const Color(0xFFF4F1EA),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.45), blurRadius: 26, offset: const Offset(0, 12))]),
        padding: EdgeInsets.all(s * .085),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC9A227), width: 1.6)),
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.black26, width: 1)),
            child: _img(),
          ),
        ),
      ));

  // 53 — Vinyl Deluxe: premium pressing — fine groove rings, a
  // gold-ringed spinning label and a metal spindle.
  Widget _vinylDeluxe(double s, Color accent) => _sq(s, child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: s, height: s,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF0A0A0E),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(.6), blurRadius: 30, offset: const Offset(0, 12))])),
          for (final f in [.88, .72, .58])
            Container(width: s * f, height: s * f,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(.055), width: 9))),
          _rotating(Container(width: s * .4, height: s * .4,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFC9A227), width: 2)),
              child: ClipOval(child: _img()))),
          Container(width: 17, height: 17,
              decoration: const BoxDecoration(shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFFF2F2F6), Color(0xFF8E8E98)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight))),
          Container(width: 5, height: 5,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2A2A32))),
        ],
      ));

  // 54 — Magazine Cover: editorial masthead + caption rules.
  Widget _magazineCover(double s, Color accent) => _sq(s, child: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(.5), blurRadius: 26, offset: const Offset(0, 12))]),
        child: ClipRRect(child: Stack(fit: StackFit.expand, children: [
          _img(),
          Positioned(left: 0, right: 0, top: 0, child: Container(
            padding: EdgeInsets.fromLTRB(s * .06, s * .05, s * .06, s * .04),
            decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(.55), Colors.transparent])),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('DHUNN', style: TextStyle(color: Colors.white, fontSize: s * .075, fontWeight: FontWeight.w900, letterSpacing: 3)),
                const Spacer(),
                Container(width: s * .05, height: s * .05,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: accent)),
              ]),
              SizedBox(height: s * .02),
              Container(height: 2, color: Colors.white.withOpacity(.85)),
            ]),
          )),
          Positioned(left: 0, right: 0, bottom: 0, child: Container(
            padding: EdgeInsets.fromLTRB(s * .06, s * .05, s * .06, s * .055),
            decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(.6), Colors.transparent])),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 3, width: s * .52, color: Colors.white),
              SizedBox(height: s * .025),
              Container(height: 3, width: s * .34, color: Colors.white.withOpacity(.65)),
            ]),
          )),
        ])),
      ));

  // 55 — Cinema Pro: letterbox widescreen, theatre clean.
  Widget _cinemaPro(double s, Color accent) => _sq(s, child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: s, height: s * .1, color: Colors.black),
          Container(width: s, height: s * .5625,
              decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(.14))),
              child: _img()),
          Container(width: s, height: 3, color: accent),
          Container(width: s, height: s * .1, color: Colors.black),
        ],
      ));

  // 56 — Studio Sleeve: record-store sleeve, accent spine.
  Widget _studioSleeve(double s, Color accent) => _sq(s, child: Container(
        decoration: BoxDecoration(color: const Color(0xFF15151C),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.5), blurRadius: 24, offset: const Offset(0, 10))]),
        child: Row(children: [
          Container(width: s * .085,
              decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [accent, Color.lerp(accent, Colors.black, .45)!])),
              child: Center(child: RotatedBox(quarterTurns: 3,
                  child: Text('DHUNN', style: TextStyle(color: Colors.white.withOpacity(.9), fontSize: s * .038, fontWeight: FontWeight.w800, letterSpacing: 2.5))))),
          Expanded(child: Padding(padding: EdgeInsets.all(s * .045),
              child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(.16))),
                  child: _img()))),
        ]),
      ));

  // 57 — Gallery Card: artwork on a museum label card.
  Widget _galleryCard(double s, Color accent) => _sq(s, child: Container(
        decoration: BoxDecoration(color: const Color(0xFFFAFAF7),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.4), blurRadius: 22, offset: const Offset(0, 10))]),
        padding: EdgeInsets.all(s * .055),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: SizedBox.expand(child: _img())),
          SizedBox(height: s * .045),
          Container(height: 3.5, width: s * .46, color: const Color(0xFF1A1A1E)),
          SizedBox(height: s * .022),
          Row(children: [
            Container(width: 8, height: 8, color: accent),
            const SizedBox(width: 6),
            Container(height: 2.5, width: s * .3, color: Colors.black38),
          ]),
          SizedBox(height: s * .012),
        ]),
      ));

}

class _DashRingPainter extends CustomPainter {
  final Color color;
  const _DashRingPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final p = Paint()
      ..color = color.withOpacity(.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dashes = 26;
    for (var i = 0; i < dashes; i += 2) {
      final a0 = i * 2 * pi / dashes;
      canvas.drawArc(Rect.fromCircle(center: c, radius: size.width / 2 - 3),
          a0, 2 * pi / dashes * .72, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant _DashRingPainter old) => old.color != color;
}

class _EqRingPainter extends CustomPainter {
  final Color color;
  final double phase;
  const _EqRingPainter(this.color, {this.phase = 0});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final p = Paint()
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    const bars = 40;
    final r0 = size.width * .44;
    for (var i = 0; i < bars; i++) {
      final a = i * 2 * pi / bars;
      final h = (sin(i * 1.7 + phase * 2 * pi) * .5 + .5) * size.width * .045 + 3;
      p.color = color.withOpacity(.35 + (h / (size.width * .05)) * .5);
      canvas.drawLine(
        c + Offset(cos(a), sin(a)) * r0,
        c + Offset(cos(a), sin(a)) * (r0 + h),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EqRingPainter old) =>
      old.color != color || old.phase != phase;
}

class _ReelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final p = Paint()
      ..color = Colors.white.withOpacity(.75)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final a = i * 2 * pi / 3;
      canvas.drawLine(
          c,
          c + Offset(cos(a), sin(a)) * (size.width / 2 - 3),
          p);
    }
    canvas.drawCircle(c, 3, Paint()..color = Colors.white.withOpacity(.8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
