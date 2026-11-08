import 'dart:math';

import 'package:flutter/material.dart';

/// Circular ripple reveal for theme switches (v2.31, his
/// request): when the user picks a new theme preset / accent /
/// mode, a filled circle in the NEW colour expands from the tap
/// point until it covers the screen; the theme itself swaps
/// underneath at ~40% of the animation, then the circle fades
/// away — the classic "ripple into the new theme" effect.
class ThemeRipple {
  static bool _active = false;

  static void show(BuildContext context, Offset center, Color color,
      {required VoidCallback onCover}) {
    if (_active) {
      onCover();
      return;
    }
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      onCover();
      return;
    }
    _active = true;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ThemeRippleView(
        center: center,
        color: color,
        onCover: onCover,
        onDone: () {
          entry.remove();
          _active = false;
        },
      ),
    );
    overlay.insert(entry);
  }

  /// Global centre of the widget [context] points at — the
  /// ripple's origin when no raw tap position is available.
  static Offset centerOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      final size = MediaQuery.of(context).size;
      return Offset(size.width / 2, size.height / 2);
    }
    return box.localToGlobal(box.size.center(Offset.zero));
  }
}

class _ThemeRippleView extends StatefulWidget {
  final Offset center;
  final Color color;
  final VoidCallback onCover;
  final VoidCallback onDone;
  const _ThemeRippleView({
    required this.center,
    required this.color,
    required this.onCover,
    required this.onDone,
  });

  @override
  State<_ThemeRippleView> createState() => _ThemeRippleViewState();
}

class _ThemeRippleViewState extends State<_ThemeRippleView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 780))
      ..addListener(() {
        if (!_covered && _c.value >= .42) {
          _covered = true;
          widget.onCover();
        }
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxR = [
          widget.center,
          Offset(size.width, widget.center.dy),
          Offset(widget.center.dx, size.height),
          Offset(size.width, size.height),
          Offset.zero,
        ]
            .map((corner) => (corner - widget.center).distance)
            .reduce(max) +
        48;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final r = maxR * Curves.easeOutCubic.transform(t);
          final fade = t < .62 ? 1.0 : 1.0 - (t - .62) / .38;
          return CustomPaint(
            size: size,
            painter: _RipplePainter(
              center: widget.center,
              radius: r,
              color: widget.color.withOpacity(.94 * fade.clamp(0.0, 1.0)),
            ),
          );
        },
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color color;
  _RipplePainter(
      {required this.center, required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;
    canvas.drawCircle(center, radius, Paint()..color = color);
    // a soft bright rim at the wavefront
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(.22 * (color.opacity))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.radius != radius || old.color != color || old.center != center;
}
