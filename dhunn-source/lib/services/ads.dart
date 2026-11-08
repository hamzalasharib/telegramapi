import 'package:flutter/services.dart';

import '../core/store.dart';

/// Monetag interstitials (v2.25): INTERSTITIAL ONLY — no push
/// ads, ever (user decision 2026-11-04). Everything user-friendly
/// is decided HERE in Dart, the native side only shows what it
/// is told to:
///
/// • the user can switch ads off completely in Settings
/// • first ad no earlier than 30 s into a session
/// • then only every 6th song start, at least 3 minutes apart
/// • at most 4 per session — a music app, not an ad app
///
/// The zone the developer received is a JS-SDK zone (libtl.com
/// loader, `show_<zone>()`), so the native side runs it in a
/// full-screen WebView activity (MonetagAdActivity) and calls it
/// MANUALLY — the SDK's `inApp` auto mode (2 ads per 6 minutes
/// on Monetag's own timer) is deliberately NOT used.
class AdsService {
  /// Monetag zone for Dhunn, from the developer's dashboard tag:
  /// <script src='//libtl.com/sdk.js' data-zone='10101719'
  ///   data-sdk='show_10101719'></script>
  static const String _zoneId = '10101719';

  static const _ch = MethodChannel('nova/ads');

  static bool get configured => _zoneId.isNotEmpty;

  static DateTime? _startedAt;
  static DateTime? _lastShown;
  static int _trackStarts = 0;
  static int _sessionShown = 0;

  static const _minSessionAge = Duration(seconds: 30);
  static const _minGap = Duration(minutes: 3);
  static const _everyNTracks = 6;
  static const _maxPerSession = 4;

  /// Call once when the app UI starts.
  static void onSessionStart(AppStore store) {
    _startedAt = DateTime.now();
    if (!configured || !store.adsEnabled) return;
    Future.delayed(_minSessionAge, () => _maybeShow(store));
  }

  /// Call whenever a genuinely new song starts playing.
  static void onTrackStart(AppStore store) {
    _trackStarts++;
    if (_trackStarts % _everyNTracks != 0) return;
    _maybeShow(store);
  }

  static Future<void> _maybeShow(AppStore store) async {
    if (!configured || !store.adsEnabled) return;
    final now = DateTime.now();
    if (_startedAt == null || now.difference(_startedAt!) < _minSessionAge) {
      return;
    }
    if (_sessionShown >= _maxPerSession) return;
    if (_lastShown != null && now.difference(_lastShown!) < _minGap) return;
    try {
      final shown =
          await _ch.invokeMethod<bool>('showInterstitial', _zoneId) ?? false;
      if (shown) {
        _lastShown = now;
        _sessionShown++;
      }
    } catch (_) {
      // No native side / SDK not wired yet — stay silent.
    }
  }
}
