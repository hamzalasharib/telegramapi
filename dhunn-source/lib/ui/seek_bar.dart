import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/store.dart';

/// Progress-bar (seek bar) designs for Now Playing (v2.30).
///
/// 24 looks, ALL drawn in code with a CustomPainter — no image
/// files, so they add ~nothing to the APK size. The themed ones
/// (Kitty, Spider Web, Arc Core, Smash) are ORIGINAL drawings in
/// the same colours/spirit as the famous characters the user
/// asked for — the characters themselves are Marvel/Sanrio
/// property and can't be bundled into an app that gets shared.
const seekStyleNames = <String>[
  'Classic', 'Neon Glow', 'Rainbow Flow', 'Waveform',
  'Heartbeat', 'Piano Keys', 'Vinyl Groove', 'Dotted Trail',
  'Kitty Cat', 'Spider Web', 'Arc Core', 'Smash Green',
  'Sunset', 'Ocean Wave', 'Galaxy', 'Gold Luxe',
  'Ice Crystal', 'Lava Flow', 'Sakura', 'Cyber Grid',
  'Candy Stripe', 'Moon Phases', 'EQ Meter', 'Hairline',
];

/// Interactive seek bar: tap or drag anywhere to seek.
class SeekBar extends StatelessWidget {
  final double progress; // 0..1
  final Color accent;
  final int style;
  final ValueChanged<double>? onSeek;
  const SeekBar({
    super.key,
    required this.progress,
    required this.accent,
    required this.style,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      double frac(Offset local) {
        const pad = 12.0;
        if (w <= 2 * pad) return 0;
        return ((local.dx - pad) / (w - 2 * pad)).clamp(0.0, 1.0);
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:
            onSeek == null ? null : (d) => onSeek!(frac(d.localPosition)),
        onHorizontalDragUpdate:
            onSeek == null ? null : (d) => onSeek!(frac(d.localPosition)),
        child: SizedBox(
          height: 32,
          width: double.infinity,
          child: CustomPaint(
            painter: SeekPainter(
                style: style,
                progress: progress.clamp(0.0, 1.0),
                accent: accent),
          ),
        ),
      );
    });
  }
}

/// Non-interactive preview (picker grid).
class SeekPreview extends StatelessWidget {
  final int style;
  final Color accent;
  final double progress;
  const SeekPreview(
      {super.key,
      required this.style,
      required this.accent,
      this.progress = 0.4});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      width: double.infinity,
      child: CustomPaint(
        painter:
            SeekPainter(style: style, progress: progress, accent: accent),
      ),
    );
  }
}

class SeekPainter extends CustomPainter {
  final int style;
  final double p; // progress 0..1
  final Color accent;
  SeekPainter({required this.style, required double progress, required this.accent})
      : p = progress;

  static const _track = Color(0x3DFFFFFF); // white24-ish
  static const _trackDim = Color(0x24FFFFFF);

  double _hash(int i) {
    final v = sin(i * 12.9898) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  void paint(Canvas cv, Size size) {
    final w = size.width;
    if (w <= 0) return;
    final cy = size.height / 2;
    const pad = 12.0;
    final x0 = pad;
    final x1 = max(pad + 1, w - pad);
    final tx = x0 + (x1 - x0) * p; // thumb / playhead x

    Paint fill(Color c) => Paint()..color = c;
    Paint stroke(Color c, double sw) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    void rrect(double x, double y, double rw, double rh, double r, Paint pt) {
      if (rw <= 0) return;
      cv.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, rw, rh), Radius.circular(r)),
          pt);
    }

    void baseTrack(double h, {Color c = _track}) =>
        rrect(x0, cy - h / 2, x1 - x0, h, h / 2, fill(c));
    void gradFill(List<Color> colors, double h, {double glow = 0}) {
      if (tx <= x0) return;
      final rect = Rect.fromLTWH(x0, cy - h / 2, tx - x0, h);
      final pt = Paint()
        ..shader = LinearGradient(colors: colors)
            .createShader(Rect.fromLTWH(x0, 0, x1 - x0, 1));
      if (glow > 0) {
        final gp = Paint()
          ..shader = pt.shader
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow);
        cv.drawRRect(
            RRect.fromRectAndRadius(rect.inflate(1), Radius.circular(h / 2 + 1)),
            gp);
      }
      cv.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(h / 2)), pt);
    }

    void thumbDot(Color c, double r, {Color? ring, double ringW = 2}) {
      cv.drawCircle(Offset(tx, cy), r, fill(c));
      if (ring != null) cv.drawCircle(Offset(tx, cy), r, stroke(ring, ringW));
    }

    switch (style) {
      case 1: // Neon Glow
        baseTrack(5, c: _trackDim);
        gradFill([accent, Color.lerp(accent, Colors.white, .45)!], 5, glow: 7);
        cv.drawCircle(Offset(tx, cy), 10,
            fill(accent.withOpacity(.35))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        thumbDot(accent, 7);
        cv.drawCircle(Offset(tx, cy), 3, fill(Colors.white));
        break;
      case 2: // Rainbow Flow
        const cols = [
          Color(0xFFFF5252), Color(0xFFFF9800), Color(0xFFFFEB3B),
          Color(0xFF69F06E), Color(0xFF40C4FF), Color(0xFFB388FF),
        ];
        final full = Rect.fromLTWH(x0, cy - 2.5, x1 - x0, 5);
        final sh = LinearGradient(colors: cols).createShader(full);
        cv.drawRRect(RRect.fromRectAndRadius(full, const Radius.circular(2.5)),
            Paint()..shader = sh..color = Colors.white.withOpacity(.30));
        if (tx > x0) {
          cv.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(x0, cy - 2.5, tx - x0, 5), const Radius.circular(2.5)),
              Paint()..shader = sh);
        }
        thumbDot(Colors.white, 6.5, ring: const Color(0xFF212121), ringW: 1.5);
        break;
      case 3: // Waveform
        const n = 44;
        final span = x1 - x0;
        for (var i = 0; i < n; i++) {
          final bx = x0 + span * (i + .5) / n;
          final bh = 4 +
              13 * (.35 + .65 * _hash(i)) * (.6 + .4 * sin(i * .8).abs());
          final played = bx <= tx;
          rrect(bx - 1.6, cy - bh / 2, 3.2, bh, 1.6,
              fill(played ? accent : _track));
        }
        cv.drawCircle(Offset(tx, cy), 3.4, fill(Colors.white));
        break;
      case 4: // Heartbeat (ECG)
        double ecg(double t) {
          final ph = (t * 5) % 1.0;
          const a = 9.0;
          if (ph < .35) return 0;
          if (ph < .45) return -a * .4 * (ph - .35) / .1;
          if (ph < .55) return -a * .4 + (a * 1.4) * (ph - .45) / .1;
          if (ph < .65) return a - a * 1.55 * (ph - .55) / .1;
          if (ph < .8) return -a * .55 + a * .55 * (ph - .65) / .15;
          return 0;
        }

        Path pathFor(double from, double to) {
          final path = Path();
          const steps = 90;
          for (var i = 0; i <= steps; i++) {
            final t = from + (to - from) * i / steps;
            final x = x0 + (x1 - x0) * t;
            final y = cy + ecg(t);
            if (i == 0) {
              path.moveTo(x, y);
            } else {
              path.lineTo(x, y);
            }
          }
          return path;
        }

        cv.drawPath(pathFor(p, 1), stroke(_track, 2));
        if (p > 0) {
          cv.drawPath(pathFor(0, p),
              stroke(accent, 2.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2));
          cv.drawPath(pathFor(0, p), stroke(accent, 2.4));
        }
        cv.drawCircle(Offset(tx, cy + ecg(p)), 4.4, fill(accent));
        cv.drawCircle(Offset(tx, cy + ecg(p)), 2, fill(Colors.white));
        break;
      case 5: // Piano Keys
        const keys = 14;
        final kw = (x1 - x0) / keys;
        for (var i = 0; i < keys; i++) {
          final kx = x0 + i * kw;
          final played = kx + kw / 2 <= tx;
          rrect(kx + .7, cy - 8, kw - 1.4, 16, 2.5,
              fill(played ? accent : Colors.white.withOpacity(.92)));
          // black keys between whites, piano pattern (skip after 3rd & 7th)
          if (i < keys - 1 && ![2, 6, 9, 13].contains(i)) {
            rrect(kx + kw - kw * .19, cy - 8, kw * .38, 9.5, 1.6,
                fill(const Color(0xFF14141C)));
          }
        }
        cv.drawLine(Offset(tx, cy - 11), Offset(tx, cy + 11),
            stroke(Colors.white, 2));
        break;
      case 6: // Vinyl Groove
        rrect(x0, cy - 6, x1 - x0, 12, 6, fill(const Color(0xFF101016)));
        for (final off in [-3.2, 0.0, 3.2]) {
          cv.drawLine(Offset(x0 + 4, cy + off), Offset(x1 - 4, cy + off),
              stroke(Colors.white.withOpacity(.07), 1));
        }
        if (tx > x0) {
          cv.save();
          cv.clipRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(x0, cy - 6, tx - x0, 12), const Radius.circular(6)));
          final sheen = Paint()
            ..shader = LinearGradient(
                    colors: [Colors.white.withOpacity(.28), Colors.white.withOpacity(.10)])
                .createShader(Rect.fromLTWH(x0, cy - 6, x1 - x0, 12));
          cv.drawRect(Rect.fromLTWH(x0, cy - 6, tx - x0, 12), sheen);
          cv.restore();
        }
        final disc = Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFFF5F5F5), const Color(0xFF9E9E9E)])
              .createShader(Rect.fromCircle(center: Offset(tx, cy), radius: 8.5));
        cv.drawCircle(Offset(tx, cy), 8.5, disc);
        cv.drawCircle(Offset(tx, cy), 8.5, stroke(Colors.black26, 1));
        cv.drawCircle(Offset(tx, cy), 2.6, fill(const Color(0xFF212121)));
        break;
      case 7: // Dotted Trail
        var i = 0;
        for (var dx = x0; dx <= x1; dx += 11, i++) {
          final played = dx <= tx;
          final near = (tx - dx).abs() < 12;
          cv.drawCircle(Offset(dx, cy), played ? (near ? 3.6 : 3) : 2.2,
              fill(played ? accent : _track));
        }
        cv.drawCircle(Offset(tx, cy), 6.5, stroke(accent, 2.4));
        cv.drawCircle(Offset(tx, cy), 6.5, fill(const Color(0xFF0B0B14)));
        cv.drawCircle(Offset(tx, cy), 2.2, fill(accent));
        break;
      case 8: // Kitty Cat (original cute cat, pink)
        baseTrack(5);
        gradFill([const Color(0xFFFF8FAB), const Color(0xFFFF4D7E)], 5);
        // tiny paw dots along the played part
        for (var dx = x0 + 12; dx < tx - 4; dx += 30) {
          cv.drawOval(
              Rect.fromCenter(center: Offset(dx, cy), width: 5, height: 3.6),
              fill(Colors.white.withOpacity(.55)));
        }
        // cat head thumb
        final c = Offset(tx, cy);
        final face = fill(const Color(0xFFFFD9E3));
        final line = stroke(const Color(0xFFFF4D7E), 1.6);
        for (final s in [-1.0, 1.0]) {
          final ear = Path()
            ..moveTo(c.dx + s * 7.5, c.dy - 5.5)
            ..lineTo(c.dx + s * 9.5, c.dy - 12.5)
            ..lineTo(c.dx + s * 2.5, c.dy - 9)
            ..close();
          cv.drawPath(ear, face);
          cv.drawPath(ear, line);
        }
        cv.drawCircle(c, 9, face);
        cv.drawCircle(c, 9, line);
        cv.drawCircle(Offset(c.dx - 3.4, c.dy - 1), 1.3, fill(const Color(0xFF5D4037)));
        cv.drawCircle(Offset(c.dx + 3.4, c.dy - 1), 1.3, fill(const Color(0xFF5D4037)));
        final nose = Path()
          ..moveTo(c.dx - 1.7, c.dy + 1.8)
          ..lineTo(c.dx + 1.7, c.dy + 1.8)
          ..lineTo(c.dx, c.dy + 3.6)
          ..close();
        cv.drawPath(nose, fill(const Color(0xFFFF4D7E)));
        for (final s in [-1.0, 1.0]) {
          cv.drawLine(Offset(c.dx + s * 6, c.dy + 1), Offset(c.dx + s * 11, c.dy + .2),
              stroke(const Color(0xFF8D6E63), 1));
          cv.drawLine(Offset(c.dx + s * 6, c.dy + 3), Offset(c.dx + s * 11, c.dy + 4.2),
              stroke(const Color(0xFF8D6E63), 1));
        }
        break;
      case 9: // Spider Web (red/blue, original web motif)
        baseTrack(5);
        gradFill([const Color(0xFFD32F2F), const Color(0xFF7B1FA2), const Color(0xFF1565C0)], 5);
        // web arcs + spokes near the playhead
        for (final r in [6.0, 11.0, 16.0]) {
          cv.drawArc(Rect.fromCircle(center: Offset(tx, cy), radius: r),
              -2.4, 4.8, false, stroke(Colors.white.withOpacity(.5), 1));
        }
        for (var k = 0; k < 6; k++) {
          final a = k * pi / 3 + .5;
          cv.drawLine(Offset(tx, cy),
              Offset(tx + 16 * cos(a), cy + 16 * sin(a)),
              stroke(Colors.white.withOpacity(.35), 1));
        }
        thumbDot(const Color(0xFF1A1A2E), 7.5, ring: const Color(0xFFE53935));
        cv.drawCircle(Offset(tx, cy), 2.4, fill(const Color(0xFFE53935)));
        break;
      case 10: // Arc Core (red/gold, glowing reactor-style thumb)
        baseTrack(5);
        gradFill([const Color(0xFFB71C1C), const Color(0xFFFF8F00), const Color(0xFFFFC107)], 5);
        cv.drawCircle(Offset(tx, cy), 11.5,
            fill(const Color(0xFF4DD0E1).withOpacity(.4))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        cv.drawCircle(Offset(tx, cy), 9, stroke(const Color(0xFFFFC107), 2.6));
        cv.drawCircle(Offset(tx, cy), 6, stroke(const Color(0xFF4DD0E1), 1.8));
        cv.drawCircle(Offset(tx, cy), 3.4, fill(const Color(0xFFE0F7FA)));
        break;
      case 11: // Smash Green (jagged energy fill, rock thumb)
        rrect(x0, cy - 3.5, x1 - x0, 7, 3.5, fill(_trackDim));
        if (tx > x0) {
          final jag = Path()..moveTo(x0, cy + 3.5);
          var up = true;
          for (var dx = x0; dx < tx; dx += 7) {
            jag.lineTo(dx, cy + (up ? -3.5 : -1));
            up = !up;
          }
          jag
            ..lineTo(tx, cy + 3.5)
            ..close();
          final pt = Paint()
            ..shader = LinearGradient(
                    colors: [const Color(0xFF2E7D32), const Color(0xFF76FF03)])
                .createShader(Rect.fromLTWH(x0, 0, x1 - x0, 1));
          cv.drawPath(jag, pt);
        }
        final rock = Path();
        const rr = 8.5;
        for (var k = 0; k < 7; k++) {
          final a = k * 2 * pi / 7 + .4;
          final rad = rr * (k.isEven ? 1 : .8);
          final pt = Offset(tx + rad * cos(a), cy + rad * sin(a));
          if (k == 0) {
            rock.moveTo(pt.dx, pt.dy);
          } else {
            rock.lineTo(pt.dx, pt.dy);
          }
        }
        rock.close();
        cv.drawPath(rock, fill(const Color(0xFF43A047)));
        cv.drawPath(rock, stroke(const Color(0xFF1B5E20), 1.6));
        cv.drawLine(Offset(tx - 3, cy - 4), Offset(tx + 1, cy + 1),
            stroke(Colors.white.withOpacity(.45), 1.2));
        cv.drawLine(Offset(tx + 1, cy + 1), Offset(tx - 1, cy + 5),
            stroke(Colors.white.withOpacity(.45), 1.2));
        break;
      case 12: // Sunset
        baseTrack(5);
        gradFill([const Color(0xFFFF9800), const Color(0xFFFF4081), const Color(0xFF7C4DFF)], 5);
        final sun = Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0xFFFFF59D), Color(0xFFFFB300)])
              .createShader(Rect.fromCircle(center: Offset(tx, cy), radius: 8.5));
        cv.drawCircle(Offset(tx, cy), 8.5, sun);
        cv.drawCircle(Offset(tx, cy), 8.5, stroke(const Color(0xFFFF7043), 1.4));
        cv.drawLine(Offset(tx - 8.5, cy + 2.5), Offset(tx + 8.5, cy + 2.5),
            stroke(const Color(0xFFFF7043), 1.4));
        break;
      case 13: // Ocean Wave
        Path wave(double from, double to, double amp) {
          final path = Path();
          const steps = 60;
          for (var i = 0; i <= steps; i++) {
            final t = from + (to - from) * i / steps;
            final x = x0 + (x1 - x0) * t;
            final y = cy + sin(t * pi * 6) * amp;
            if (i == 0) {
              path.moveTo(x, y);
            } else {
              path.lineTo(x, y);
            }
          }
          return path;
        }

        cv.drawPath(wave(p, 1, 3.4), stroke(_track, 2));
        if (p > 0) {
          final area = wave(0, p, 3.4)
            ..lineTo(tx, cy + 8)
            ..lineTo(x0, cy + 8)
            ..close();
          cv.drawPath(
              area,
              Paint()
                ..shader = LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF29B6F6).withOpacity(.85),
                          const Color(0xFF0277BD).withOpacity(.35)
                        ])
                    .createShader(Rect.fromLTWH(x0, cy - 6, x1 - x0, 14)));
          cv.drawPath(wave(0, p, 3.4), stroke(const Color(0xFF4FC3F7), 2.2));
        }
        thumbDot(Colors.white, 5.5, ring: const Color(0xFF039BE5), ringW: 1.6);
        break;
      case 14: // Galaxy
        rrect(x0, cy - 3.5, x1 - x0, 7, 3.5, fill(const Color(0xFF241543)));
        for (var i = 0; i < 26; i++) {
          final sx = x0 + (x1 - x0) * _hash(i * 3 + 1);
          final sy = cy - 2.6 + _hash(i * 7 + 2) * 5.2;
          cv.drawCircle(Offset(sx, sy), _hash(i) > .8 ? 1.3 : .8,
              fill(Colors.white.withOpacity(.75)));
        }
        gradFill([const Color(0xFF7C4DFF), const Color(0xFFE040FB)], 7);
        cv.drawOval(
            Rect.fromCenter(center: Offset(tx, cy), width: 23, height: 8),
            stroke(const Color(0xFFFFD54F), 1.6));
        thumbDot(const Color(0xFFB388FF), 7);
        cv.drawCircle(Offset(tx - 2, cy - 2), 1.6, fill(Colors.white.withOpacity(.7)));
        break;
      case 15: // Gold Luxe
        rrect(x0, cy - 2.5, x1 - x0, 5, 2.5, fill(const Color(0xFF3A2E12)));
        cv.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x0, cy - 2.5, x1 - x0, 5), const Radius.circular(2.5)),
            stroke(const Color(0xFFD4A017), .8));
        gradFill([const Color(0xFFD4A017), const Color(0xFFFFECB3), const Color(0xFFFFD700)], 5);
        final dia = Path()
          ..moveTo(tx, cy - 9)
          ..lineTo(tx + 6.5, cy)
          ..lineTo(tx, cy + 9)
          ..lineTo(tx - 6.5, cy)
          ..close();
        cv.drawPath(
            dia,
            Paint()
              ..shader = const LinearGradient(
                      colors: [Color(0xFFFFECB3), Color(0xFFD4A017)])
                  .createShader(Rect.fromLTWH(tx - 7, cy - 9, 14, 18)));
        cv.drawPath(dia, stroke(Colors.white.withOpacity(.8), 1));
        break;
      case 16: // Ice Crystal
        baseTrack(5, c: _trackDim);
        gradFill([const Color(0xFFE0F7FA), const Color(0xFF4DD0E1)], 5);
        for (var dx = x0 + 16; dx < tx - 2; dx += 34) {
          final sp = stroke(Colors.white.withOpacity(.85), 1.2);
          cv.drawLine(Offset(dx - 3, cy), Offset(dx + 3, cy), sp);
          cv.drawLine(Offset(dx, cy - 3), Offset(dx, cy + 3), sp);
        }
        cv.drawCircle(Offset(tx, cy), 8.5, fill(const Color(0xFFE0F7FA)));
        cv.drawCircle(Offset(tx, cy), 8.5, stroke(const Color(0xFF0288D1), 1.4));
        final flake = stroke(const Color(0xFF0288D1), 1.3);
        for (var k = 0; k < 3; k++) {
          final a = k * pi / 3;
          cv.drawLine(
              Offset(tx - 5 * cos(a), cy - 5 * sin(a)),
              Offset(tx + 5 * cos(a), cy + 5 * sin(a)),
              flake);
        }
        break;
      case 17: // Lava Flow
        rrect(x0, cy - 4, x1 - x0, 8, 4, fill(const Color(0xFF1A0E0A)));
        if (tx > x0) {
          cv.save();
          cv.clipRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(x0, cy - 4, tx - x0, 8), const Radius.circular(4)));
          cv.drawRect(Rect.fromLTWH(x0, cy - 4, tx - x0, 8),
              fill(const Color(0xFFBF360C)));
          var i = 0;
          for (var dx = x0 + 6; dx < tx; dx += 17, i++) {
            cv.drawCircle(Offset(dx, cy + (i.isEven ? -1 : 1.4)), 2.6 + _hash(i) * 1.8,
                fill(i.isEven ? const Color(0xFFFF6D00) : const Color(0xFFFF9100)));
          }
          cv.restore();
        }
        cv.drawCircle(Offset(tx, cy), 8,
            fill(const Color(0xFFFF9100))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        thumbDot(const Color(0xFFFFB74D), 6.8, ring: const Color(0xFF4E2600), ringW: 1.6);
        break;
      case 18: // Sakura
        baseTrack(5);
        gradFill([const Color(0xFFFCE4EC), const Color(0xFFF48FB1)], 5);
        for (var i = 0; i < 7; i++) {
          final dx = x0 + (x1 - x0) * (i + .5) / 7;
          cv.save();
          cv.translate(dx, cy - 6.5);
          cv.rotate(i * .9);
          cv.drawOval(Rect.fromCenter(center: Offset.zero, width: 5.4, height: 3.4),
              fill(const Color(0xFFF8BBD0).withOpacity(.8)));
          cv.restore();
        }
        // flower thumb: 5 petals + golden heart
        for (var k = 0; k < 5; k++) {
          final a = -pi / 2 + k * 2 * pi / 5;
          final pc = Offset(tx + 5.2 * cos(a), cy + 5.2 * sin(a));
          cv.save();
          cv.translate(pc.dx, pc.dy);
          cv.rotate(a + pi / 2);
          cv.drawOval(
              Rect.fromCenter(center: Offset.zero, width: 5.6, height: 8),
              fill(const Color(0xFFF48FB1)));
          cv.restore();
        }
        cv.drawCircle(Offset(tx, cy), 2.6, fill(const Color(0xFFFFD54F)));
        break;
      case 19: // Cyber Grid
        rrect(x0, cy - 4.5, x1 - x0, 9, 2, fill(const Color(0xFF0D2B33)));
        for (var dx = x0 + 4; dx < x1; dx += 9) {
          cv.drawLine(Offset(dx, cy - 4.5), Offset(dx, cy + 4.5),
              stroke(const Color(0xFF00E5FF).withOpacity(.22), 1));
        }
        if (tx > x0) {
          cv.save();
          cv.clipRect(Rect.fromLTWH(x0, cy - 4.5, tx - x0, 9));
          cv.drawRect(Rect.fromLTWH(x0, cy - 4.5, tx - x0, 9),
              fill(const Color(0xFF00E5FF).withOpacity(.75))
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
          cv.drawRect(Rect.fromLTWH(x0, cy - 4.5, tx - x0, 9),
              fill(const Color(0xFF00E5FF).withOpacity(.9)));
          cv.restore();
        }
        cv.drawRect(Rect.fromCenter(center: Offset(tx, cy), width: 13, height: 13),
            fill(const Color(0xFF06222A)));
        cv.drawRect(Rect.fromCenter(center: Offset(tx, cy), width: 13, height: 13),
            stroke(const Color(0xFF00E5FF), 2));
        cv.drawCircle(Offset(tx, cy), 2.2, fill(const Color(0xFF00E5FF)));
        break;
      case 20: // Candy Stripe
        baseTrack(5.5);
        if (tx > x0) {
          cv.save();
          cv.clipRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(x0, cy - 2.75, tx - x0, 5.5), const Radius.circular(2.75)));
          var i = 0;
          for (var dx = x0 - 8; dx < tx + 8; dx += 9, i++) {
            final stripe = Path()
              ..moveTo(dx, cy + 6)
              ..lineTo(dx + 4.5, cy - 6)
              ..lineTo(dx + 9, cy - 6)
              ..lineTo(dx + 4.5, cy + 6)
              ..close();
            cv.drawPath(stripe,
                fill(i.isEven ? const Color(0xFFFF5252) : Colors.white));
          }
          cv.restore();
        }
        cv.drawCircle(Offset(tx, cy), 7.5, fill(Colors.white));
        cv.drawArc(Rect.fromCircle(center: Offset(tx, cy), radius: 7.5),
            -pi / 2, pi, true, fill(const Color(0xFFFF5252)));
        cv.drawCircle(Offset(tx, cy), 7.5, stroke(const Color(0xFFE0E0E0), 1.2));
        break;
      case 21: // Moon Phases
        rrect(x0, cy - 3, x1 - x0, 6, 3, fill(const Color(0xFF263238)));
        cv.drawLine(Offset(x0, cy), Offset(tx, cy),
            stroke(const Color(0xFFFFF9C4).withOpacity(.55), 2));
        for (var i = 0; i < 5; i++) {
          final mx = x0 + (x1 - x0) * i / 4;
          cv.drawCircle(Offset(mx, cy), 4, fill(const Color(0xFFFFF9C4)));
          if (i > 0 && i < 4) {
            // crescent shadow, deeper towards the ends
            final shift = (2 - i).abs() * 1.6 + 1.2;
            cv.drawCircle(Offset(mx + (i < 2 ? -shift : shift), cy), 3.6,
                fill(const Color(0xFF263238)));
          }
        }
        thumbDot(const Color(0xFFFFF9C4), 8, ring: const Color(0xFFFFECB3));
        cv.drawCircle(Offset(tx - 2.5, cy - 2), 1.3, fill(const Color(0xFFE0D6A8)));
        cv.drawCircle(Offset(tx + 3, cy + 3), 1, fill(const Color(0xFFE0D6A8)));
        break;
      case 22: // EQ Meter
        const n = 18;
        final bw = (x1 - x0) / n;
        for (var i = 0; i < n; i++) {
          final bx = x0 + i * bw;
          final f = i / (n - 1);
          final col = f < .5
              ? const Color(0xFF69F06E)
              : (f < .78 ? const Color(0xFFFFEB3B) : const Color(0xFFFF5252));
          final played = bx + bw / 2 <= tx;
          rrect(bx + 1, cy - 6.5, bw - 2, 13, 2,
              fill(played ? col : col.withOpacity(.16)));
        }
        break;
      case 23: // Hairline
        cv.drawLine(Offset(x0, cy), Offset(x1, cy), stroke(_track, 1.6));
        cv.drawLine(Offset(x0, cy), Offset(tx, cy), stroke(Colors.white, 1.8));
        cv.drawCircle(Offset(tx, cy), 3, fill(Colors.white));
        break;
      default: // 0 Classic
        baseTrack(4);
        if (tx > x0) {
          rrect(x0, cy - 2, tx - x0, 4, 2, fill(Colors.white));
        }
        thumbDot(Colors.white, 6);
    }
  }

  @override
  bool shouldRepaint(SeekPainter old) =>
      old.p != p || old.style != style || old.accent != accent;
}

/// Picker: 2-column grid of LIVE animated previews (the progress
/// sweeps back and forth), tap to choose. Entry points: Settings
/// -> Player & Lyrics, and long-press on the player's seek bar.
class SeekStylesScreen extends StatefulWidget {
  const SeekStylesScreen({super.key});

  @override
  State<SeekStylesScreen> createState() => _SeekStylesScreenState();
}

class _SeekStylesScreenState extends State<SeekStylesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Progress bar style')),
      body: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
              '24 designs for the player seek bar — all drawn in code, no images, so the app stays light. Tap one to use it.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey)),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final demo = .18 + .64 * _ctrl.value;
              return GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.55,
                ),
                itemCount: seekStyleNames.length,
                itemBuilder: (_, i) {
                  final selected = store.seekStyle == i;
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => store.update(() => store.seekStyle = i),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF17171F),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: selected ? accent : Colors.white12,
                            width: selected ? 2 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Center(
                              child: SeekPreview(
                                  style: i, accent: accent, progress: demo),
                            ),
                          ),
                          Row(children: [
                            Expanded(
                              child: Text(seekStyleNames[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700)),
                            ),
                            if (selected)
                              Icon(Icons.check_circle,
                                  size: 17, color: accent),
                          ]),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
