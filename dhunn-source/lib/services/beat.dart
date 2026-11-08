import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Beat energy feed for the Fluid Beat background (v2.12).
///
/// Primary source: the native Visualizer's FFT bass energy over the
/// `nova/viz` EventChannel (real beat sync with the playing audio).
/// If that's unavailable (permission denied, OEM blocks the
/// Visualizer, session not ready), a synthetic pulse at ~118 BPM
/// keeps the background alive — better an approximate beat than a
/// frozen screen. [energy] is a smoothed 0..1 level: fast attack so
/// blobs jump ON the beat, slow decay so they melt back down.
class BeatService {
  static const _channel = EventChannel('nova/viz');

  final ValueNotifier<double> energy = ValueNotifier<double>(0);
  double _level = 0;

  StreamSubscription<dynamic>? _sub;
  StreamSubscription<int?>? _sessSub;
  Timer? _synth;
  Timer? _watchdog;
  bool _nativeLive = false;
  bool _playing = false;
  int _beatCount = 0;

  /// One smoothing step (fast attack, slow release).
  static double smooth(double level, double raw) {
    if (raw > level) return level + (raw - level) * 0.85;
    return level * 0.86 + raw * 0.02;
  }

  void _feed(double raw) {
    // Gain (v2.13): the pulse must be FELT — amplify before smoothing.
    _level = smooth(_level, (raw * 1.35).clamp(0, 1));
    energy.value = _level;
  }

  /// [sessions] is the player's audio-session stream; the native
  /// visualizer attaches to the latest session id.
  void start(Stream<int?> sessions) {
    stop();
    _sessSub = sessions.listen((id) {
      if (id != null && id != 0) _subscribe(id);
    });
    // If no native event arrives soon, go synthetic.
    _watchdog = Timer(const Duration(seconds: 2), () {
      if (!_nativeLive) _startSynth();
    });
  }

  void _subscribe(int sessionId) {
    _sub?.cancel();
    _sub = _channel.receiveBroadcastStream(sessionId).listen(
      (e) {
        _nativeLive = true;
        _synth?.cancel();
        _synth = null;
        if (e is num) _feed(e.toDouble());
      },
      onError: (_) {
        _nativeLive = false;
        _startSynth();
      },
    );
  }

  void setPlaying(bool playing) {
    _playing = playing;
    if (!playing) {
      // let the level melt away instead of freezing mid-beat
      _feed(0);
    } else if (!_nativeLive) {
      _startSynth();
    }
  }

  void _startSynth() {
    if (_synth != null || _nativeLive) return;
    _beatCount = 0;
    // ~118 BPM: a beat every ~508 ms; sample the envelope at 50 ms.
    _synth = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_playing) {
        _feed(0);
        return;
      }
      _beatCount++;
      // 10 ticks per beat; sharp pulse at the top, easing down.
      final phase = (_beatCount % 10) / 10.0;
      final pulse = math.pow(1 - phase, 2.2).toDouble();
      // every 4th beat a little softer, like a real bar
      final bar = (_beatCount ~/ 10) % 4 == 3 ? 0.75 : 1.0;
      _feed(pulse * bar);
    });
  }

  /// Restart the native subscription (e.g. after the mic permission
  /// was just granted).
  void restart(Stream<int?> sessions) => start(sessions);

  void stop() {
    _sub?.cancel();
    _sub = null;
    _sessSub?.cancel();
    _sessSub = null;
    _synth?.cancel();
    _synth = null;
    _watchdog?.cancel();
    _watchdog = null;
    _nativeLive = false;
    _level = 0;
    energy.value = 0;
  }
}
