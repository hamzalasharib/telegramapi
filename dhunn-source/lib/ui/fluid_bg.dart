import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/models.dart';
import '../services/beat.dart';
import '../services/dominant.dart';
import '../services/player.dart';

/// Fluid Beat background (v2.12): liquid blobs wearing the ALBUM
/// COVER's own colours (CoverPalette), drifting like slow lava and
/// PULSING ON THE REAL BEAT — bass energy streamed from the native
/// Visualizer via BeatService (synthetic pulse as fallback). The
/// blobs render into a blurred layer so their edges melt into each
/// other like liquid; palette changes cross-fade over ~700 ms.
class FluidBeatBg extends StatefulWidget {
  final MediaItem item;
  final Color accent;
  final bool playing;
  final PlayerService player;
  // When [sharedBeat] is given, the CALLER owns the BeatService
  // lifecycle (start/stop) — used by MainShell for the app-wide
  // background (v2.19) so the whole app shares ONE visualizer feed.
  final BeatService? sharedBeat;
  final Color topScrim;
  final Color bottomScrim;
  const FluidBeatBg(
      {required this.item,
      required this.accent,
      required this.playing,
      required this.player,
      this.sharedBeat,
      this.topScrim = const Color(0x2A000000),
      this.bottomScrim = const Color(0x73000000)});
  @override
  State<FluidBeatBg> createState() => FluidBeatBgState();
}

class FluidBeatBgState extends State<FluidBeatBg>
    with SingleTickerProviderStateMixin {
  // 120 s loop; all angular speeds are multiples of 2π/120 so the
  // drift is perfectly continuous across the wrap.
  late final AnimationController _t =
      AnimationController(vsync: this, duration: const Duration(seconds: 120));
  late final BeatService _beat;
  bool _ownsBeat = false;
  List<Color> _from = const [];
  List<Color> _to = const [];
  DateTime _switchAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _paletteFor;

  @override
  void initState() {
    super.initState();
    _beat = widget.sharedBeat ?? BeatService();
    _ownsBeat = widget.sharedBeat == null;
    if (widget.playing) _t.repeat();
    if (_ownsBeat) {
      _beat.start(widget.player.player.androidAudioSessionIdStream);
    }
    _beat.setPlaying(widget.playing);
    _loadPalette();
    // The Visualizer needs RECORD_AUDIO; ask once, then re-attach.
    if (_ownsBeat) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final st = await Permission.microphone.request();
        if (st.isGranted && mounted) {
          _beat.restart(widget.player.player.androidAudioSessionIdStream);
          _beat.setPlaying(widget.playing);
        }
      });
    }
  }

  Future<void> _loadPalette() async {
    final item = widget.item;
    _paletteFor = item.id;
    final colors = await CoverPalette.of(item, fallback: widget.accent);
    if (!mounted || _paletteFor != item.id) return;
    setState(() {
      _from = _to.isEmpty ? colors : _displayColors();
      _to = colors;
      _switchAt = DateTime.now();
    });
  }

  List<Color> _displayColors() {
    if (_to.isEmpty) return [widget.accent, widget.accent, widget.accent];
    final f = (DateTime.now().difference(_switchAt).inMilliseconds / 700)
        .clamp(0, 1)
        .toDouble();
    return List.generate(
        3, (i) => Color.lerp(_from[i], _to[i], f) ?? _to[i]);
  }

  @override
  void didUpdateWidget(covariant FluidBeatBg old) {
    super.didUpdateWidget(old);
    if (widget.item.id != old.item.id) _loadPalette();
    if (widget.playing != old.playing) {
      _beat.setPlaying(widget.playing);
      if (widget.playing && !_t.isAnimating) {
        _t.repeat();
      } else if (!widget.playing && _t.isAnimating) {
        _t.stop();
      }
    }
  }

  @override
  void dispose() {
    if (_ownsBeat) _beat.stop();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_t, _beat.energy]),
      builder: (_, __) {
        final colors = _displayColors();
        final deep = Color.lerp(colors[0], Colors.black, .84 - .13 * _beat.energy.value)!;
        final time = _t.value * 120; // seconds, wraps seamlessly
        return Stack(fit: StackFit.expand, children: [
          Container(color: deep),
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: CustomPaint(
              painter: FluidPainter(
                  time: time, energy: _beat.energy.value, colors: colors),
              size: Size.infinite,
            ),
          ),
          // readability gradient for controls & lyrics
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.topScrim, widget.bottomScrim],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class FluidPainter extends CustomPainter {
  final double time;
  final double energy;
  final List<Color> colors;
  FluidPainter({required this.time, required this.energy, required this.colors});

  // bx, by (fractions), radius (× width), drift speeds, phase,
  // colour index, beat-pulse factor
  static const _blobs = <(double, double, double, double, double, double, int, double)>[
    (0.22, 0.20, 0.62, 1, 2, 0.0, 0, 1.0),
    (0.82, 0.34, 0.55, 2, 1, 1.7, 1, 0.8),
    (0.55, 0.78, 0.66, 1, 3, 3.4, 2, 1.15),
    (0.12, 0.88, 0.46, 3, 2, 5.1, 1, 0.65),
    (0.92, 0.92, 0.42, 2, 3, 2.6, 0, 0.9),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const w = 2 * pi / 120; // angular base for seamless looping
    for (final b in _blobs) {
      final (bx, by, r, sx, sy, phase, ci, pf) = b;
      final cx = (bx + 0.13 * sin(time * w * sx + phase)) * size.width;
      final cy = (by + 0.11 * cos(time * w * sy + phase * 1.3)) * size.height;
      final radius = r * size.width *
          (1 + 0.05 * sin(time * w * 2 + phase) + 0.32 * energy * pf);
      final color = colors[ci % colors.length];
      final paint = Paint()
        ..shader = RadialGradient(colors: [
          color.withOpacity(.48 + .47 * energy),
          color.withOpacity(0),
        ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FluidPainter old) =>
      old.time != time || old.energy != energy || old.colors != colors;
}

