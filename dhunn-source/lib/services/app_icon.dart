import 'package:flutter/services.dart';

/// Launcher icon variants: v2.21 replaced the first two with
/// the user's own purple artwork — Purple Note (default) and
/// Headphones — Sunset / Violet remain. Switching uses Android
/// activity-aliases through the Kotlin 'setIcon' method.
class AppIcon {
  static const _media = MethodChannel('nova/media');

  static const names = ['Purple Note', 'Headphones', 'Sunset', 'Violet'];
  static const assets = [
    'assets/icon.png',
    'assets/icon_ocean.png',
    'assets/icon_sunset.png',
    'assets/icon_violet.png',
  ];

  static Future<bool> setVariant(int variant) async {
    try {
      return await _media
              .invokeMethod<bool>('setIcon', {'variant': variant}) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
