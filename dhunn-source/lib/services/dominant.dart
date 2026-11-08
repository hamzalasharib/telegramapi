import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/models.dart';

/// Extracts the dominant colour of a track's artwork (tiny downscaled
/// average weighted by saturation) — used to tint the mini player with
/// a gradient picked from the cover itself. Cached per track id.
class DominantColor {
  static final _cache = <String, Color?>{};

  static Future<Color?> of(MediaItem item) async {
    if (_cache.containsKey(item.id)) return _cache[item.id];
    Color? result;
    try {
      final url = item.artworkUrl;
      if (url != null && url.startsWith('/')) {
        final bytes = await File(url).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes,
            targetWidth: 12, targetHeight: 12);
        final frame = await codec.getNextFrame();
        final data = await frame.image
            .toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data != null) {
          double r = 0, g = 0, b = 0, wSum = 0;
          for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
            final pr = data.getUint8(i).toDouble();
            final pg = data.getUint8(i + 1).toDouble();
            final pb = data.getUint8(i + 2).toDouble();
            final mx = [pr, pg, pb].reduce((a, c) => a > c ? a : c);
            final mn = [pr, pg, pb].reduce((a, c) => a < c ? a : c);
            final lum = (0.299 * pr + 0.587 * pg + 0.114 * pb) / 255;
            final sat = mx == 0 ? 0 : (mx - mn) / mx;
            // Favour vivid mid-bright pixels; still count dull ones a bit.
            final w = 0.15 + sat * (1 - (lum - 0.45).abs());
            r += pr * w;
            g += pg * w;
            b += pb * w;
            wSum += w;
          }
          if (wSum > 0) {
            result = Color.fromARGB(
                255, (r / wSum).round(), (g / wSum).round(), (b / wSum).round());
          }
          frame.image.dispose();
        }
        codec.dispose();
      }
    } catch (_) {
      result = null;
    }
    _cache[item.id] = result;
    return result;
  }
}

/// Normalise a cover colour for use as a UI accent: guaranteed
/// saturation and mid lightness so themes never go grey or blown.
Color vividAccent(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withSaturation(hsl.saturation < 0.35 ? 0.35 : hsl.saturation)
      .withLightness(hsl.lightness.clamp(0.36, 0.60))
      .toColor();
}

/// A 3-colour palette pulled from the track's OWN album cover —
/// drives the Fluid Beat player background (v2.12): the liquid blobs
/// wear the cover's colours, not the theme's. Colours are picked by
/// hue-bucket clustering weighted toward vivid pixels, so a red
/// cover gives red/orange/amber blobs, a blue cover blue/cyan ones.
class CoverPalette {
  static final _cache = <String, List<Color>>{};

  /// Always returns exactly 3 colours (fallbacks are hue shifts of
  /// the dominant colour, or of the theme accent when no art exists).
  static Future<List<Color>> of(MediaItem item, {Color? fallback}) async {
    final hit = _cache[item.id];
    if (hit != null) return hit;
    final base = fallback ?? const Color(0xFF1DB954);
    var colors = <Color>[];
    try {
      final url = item.artworkUrl;
      if (url != null && url.startsWith('/')) {
        final bytes = await File(url).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes,
            targetWidth: 40, targetHeight: 40);
        final frame = await codec.getNextFrame();
        final data =
            await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data != null) {
          // 12 hue buckets; accumulate weighted RGB per bucket.
          const buckets = 12;
          final wr = List<double>.filled(buckets, 0);
          final wg = List<double>.filled(buckets, 0);
          final wb = List<double>.filled(buckets, 0);
          final ws = List<double>.filled(buckets, 0);
          for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
            final r = data.getUint8(i).toDouble();
            final g = data.getUint8(i + 1).toDouble();
            final b = data.getUint8(i + 2).toDouble();
            final c = Color.fromARGB(255, r.round(), g.round(), b.round());
            final hsl = HSLColor.fromColor(c);
            if (hsl.saturation < 0.22 || hsl.lightness < 0.08 || hsl.lightness > 0.94) {
              continue; // skip greys, near-black and blown whites
            }
            final idx = (hsl.hue / 360 * buckets).floor() % buckets;
            final w = hsl.saturation * (1 - (hsl.lightness - 0.5).abs());
            wr[idx] += r * w;
            wg[idx] += g * w;
            wb[idx] += b * w;
            ws[idx] += w;
          }
          final order = List<int>.generate(buckets, (i) => i)
            ..sort((a, b) => ws[b].compareTo(ws[a]));
          final picked = <int>[];
          for (final idx in order) {
            if (ws[idx] <= 0) break;
            // keep hue families ~50 degrees apart (circular) for variety
            bool farEnough(int p) {
              final d = (p - idx).abs() * 30;
              final circ = d > 180 ? 360 - d : d;
              return circ >= 50;
            }
            if (picked.every(farEnough)) picked.add(idx);
            if (picked.length == 3) break;
          }
          colors = picked
              .map((idx) => Color.fromARGB(255, (wr[idx] / ws[idx]).round(),
                  (wg[idx] / ws[idx]).round(), (wb[idx] / ws[idx]).round()))
              .toList();
        }
        frame.image.dispose();
        codec.dispose();
      }
    } catch (_) {
      colors = <Color>[];
    }
    if (colors.isEmpty) {
      final dom = await DominantColor.of(item) ?? base;
      colors = [dom];
    }
    // Normalise vividness: fluid blobs look best saturated & mid-lit.
    colors = colors.map((c) {
      final hsl = HSLColor.fromColor(c);
      return hsl
          .withSaturation(math.max(hsl.saturation, 0.55))
          .withLightness(hsl.lightness.clamp(0.38, 0.62))
          .toColor();
    }).toList();
    while (colors.length < 3) {
      final hsl = HSLColor.fromColor(colors.first);
      colors.add(hsl
          .withHue((hsl.hue + 45.0 * colors.length) % 360)
          .toColor());
    }
    _cache[item.id] = colors;
    return colors;
  }
}
