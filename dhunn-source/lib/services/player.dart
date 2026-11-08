import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models.dart' as m;
import 'eq.dart';

/// Audio engine v2 — rebuilt after v1.0 field reports of "songs list but
/// don't play" on some devices:
///  • The player uses a PLAIN pipeline (no just_audio audio-FX — some OEM
///    ROMs reject those and broke playback in v1). The equalizer instead
///    runs as a NATIVE Android audiofx effect on the player's audio
///    session (see EqService / EqChannel.kt), independent of the pipeline.
///  • `play()` is never awaited (its future only completes when playback
///    ends). Index/history update immediately.
///  • Local audio plays from MediaStore content URIs (scoped-storage safe).
///  • If a queue load fails, it retries with a single-source load of the
///    tapped item, and every failure is surfaced to the UI via [lastError]
///    and the error callback — nothing fails silently anymore.
class PlayerService extends ChangeNotifier {
  AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;
  String? lastError;

  // ---- Load race guard (v2.26) ----
  // Rapid repeated taps used to fire OVERLAPPING setAudioSource
  // calls; the engine aborts the earlier load, and that abort was
  // surfaced as "Playback failed: Connection aborted". Loads are
  // now coalesced (while one runs, only the LATEST tap is kept)
  // and abort/interrupt errors from superseded loads are benign.
  bool _playLoop = false;
  _PendingPlay? _pendingPlay;

  static bool _benignLoadError(Object e) {
    if (e is PlayerInterruptedException) return true;
    final s = e.toString().toLowerCase();
    return s.contains('abort') || s.contains('interrupt');
  }

  List<m.MediaItem> queue = [];
  int currentIndex = -1;
  Timer? _sleepTimer;
  int? sleepMinutes;
  double speed = 1.0;
  StreamSubscription<dynamic>? _errSub;
  StreamSubscription<int?>? _sessSub;
  StreamSubscription<Duration>? _posSub;

  // ---- Session persistence (v2.9) ----
  // The queue + current track + EXACT position are saved continuously
  // so closing the app no longer loses the song: on the next launch
  // the mini player is already holding the same track at the same
  // timeline point, paused and ready to resume.
  static const _kQueue = 'sessionQueueIds';
  static const _kIndex = 'sessionIndex';
  static const _kPos = 'sessionPositionMs';
  bool _loaded = false; // an audio source is loaded in the engine
  Duration _pendingPos = Duration.zero; // restored position awaiting load
  DateTime _lastPosSave = DateTime.fromMillisecondsSinceEpoch(0);

  PlayerService() {
    _wire(_player);
    _posSub = _player.positionStream.listen((pos) {
      final now = DateTime.now();
      if (now.difference(_lastPosSave).inSeconds >= 3) {
        _lastPosSave = now;
        saveSession();
      }
    });
  }

  Future<void> saveSession() async {
    if (queue.isEmpty || currentIndex < 0 || currentIndex >= queue.length) return;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kQueue, jsonEncode(queue.map((e) => e.id).toList()));
      await sp.setInt(_kIndex, currentIndex);
      await sp.setInt(_kPos, _player.position.inMilliseconds);
    } catch (_) {}
  }

  Future<void> _clearSession() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_kQueue);
      await sp.remove(_kIndex);
      await sp.remove(_kPos);
    } catch (_) {}
  }

  /// Load the saved queue into the engine at the saved position,
  /// PAUSED. Called once at startup (see main.dart).
  Future<void> restoreSession(m.MediaItem? Function(String id) byId) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kQueue);
      if (raw == null) return;
      final ids = (jsonDecode(raw) as List).cast<String>();
      if (ids.isEmpty) return;
      final items = ids
          .map(byId)
          .whereType<m.MediaItem>()
          .where((i) => i.source.isNotEmpty)
          .toList();
      if (items.isEmpty) return;
      final savedIdx = sp.getInt(_kIndex) ?? 0;
      final savedId =
          (savedIdx >= 0 && savedIdx < ids.length) ? ids[savedIdx] : ids.first;
      var start = items.indexWhere((e) => e.id == savedId);
      if (start < 0) start = 0;
      _pendingPos = Duration(milliseconds: sp.getInt(_kPos) ?? 0);
      queue = items;
      currentIndex = start;
      notifyListeners();
      await _loadCurrent();
    } catch (_) {
      // a corrupt session must never block startup
    }
  }

  /// (Re)load the current queue into the engine at [_pendingPos].
  Future<void> _loadCurrent() async {
    if (queue.isEmpty || currentIndex < 0) return;
    try {
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: queue.map(_sourceFor).toList()),
        initialIndex: currentIndex,
        initialPosition: _pendingPos,
      );
      _loaded = true;
    } catch (_) {
      try {
        await _player.setAudioSource(_sourceFor(queue[currentIndex]),
            initialPosition: _pendingPos);
        queue = [queue[currentIndex]];
        currentIndex = 0;
        _loaded = true;
      } catch (_) {
        _loaded = false; // toggle() will retry the load on demand
      }
    }
    notifyListeners();
  }

  void _wire(AudioPlayer p) {
    p.currentIndexStream.listen((i) {
      if (i != null) currentIndex = i;
      notifyListeners();
      saveSession();
    });
    p.playerStateStream.listen((st) {
      notifyListeners();
      if (!st.playing) saveSession();
    });
    _errSub?.cancel();
    _errSub = p.playbackEventStream.listen((_) {}, onError: (Object e) {
      if (_benignLoadError(e)) return; // superseded load — not a failure
      lastError = 'Playback error: $e';
      notifyListeners();
    });
    // Native audio-FX equalizer follows the player's audio session.
    _sessSub?.cancel();
    _sessSub = p.androidAudioSessionIdStream.listen((id) {
      if (id != null && id != 0) EqService.instance.attach(id);
    });
  }

  m.MediaItem? get current =>
      (currentIndex >= 0 && currentIndex < queue.length) ? queue[currentIndex] : null;
  bool get playing => _player.playing;
  bool get hasQueue => queue.isNotEmpty;

  /// Swap in better artwork for a queued track (HD cover downloads
  /// finish in the background — the playing UI should refresh).
  void updateArtwork(String id, String path) {
    var changed = false;
    for (var i = 0; i < queue.length; i++) {
      if (queue[i].id == id && queue[i].artworkUrl != path) {
        queue[i] = queue[i].copyWith(artworkUrl: path);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  static AudioSource _sourceFor(m.MediaItem item) {
    final tag = MediaItem(
      id: item.id,
      title: item.title,
      artist: item.artist.isEmpty ? null : item.artist,
      album: item.album.isEmpty ? null : item.album,
      // Notification/lock-screen artwork: local songs carry a cached
      // thumbnail FILE path (or a MediaStore content URI); both work as
      // artUri — without this the notification shows a placeholder.
      artUri: item.artworkUrl == null || item.artworkUrl!.isEmpty
          ? null
          : item.artworkUrl!.startsWith('/')
              ? Uri.file(item.artworkUrl!)
              : Uri.tryParse(item.artworkUrl!),
      duration: item.duration == Duration.zero ? null : item.duration,
    );
    if (item.source.startsWith('content://')) {
      return AudioSource.uri(Uri.parse(item.source), tag: tag);
    }
    if (item.isLocal) return AudioSource.file(item.source, tag: tag);
    return AudioSource.uri(Uri.parse(item.source), tag: tag);
  }

  Future<void> playQueue(List<m.MediaItem> items, int index,
      {required void Function(m.MediaItem) onPlayed,
      required Future<void> Function(String msg) onError}) async {
    // Coalesce: if a load is already running, just replace the
    // pending request — the newest tap wins, loads never overlap.
    _pendingPlay = _PendingPlay(items, index, onPlayed, onError);
    if (_playLoop) return;
    _playLoop = true;
    try {
      while (_pendingPlay != null) {
        final req = _pendingPlay!;
        _pendingPlay = null;
        await _playQueueOnce(req.items, req.index,
            onPlayed: req.onPlayed, onError: req.onError);
      }
    } finally {
      _playLoop = false;
    }
  }

  Future<void> _playQueueOnce(List<m.MediaItem> items, int index,
      {required void Function(m.MediaItem) onPlayed,
      required Future<void> Function(String msg) onError}) async {
    lastError = null;
    // Offline player: every item already carries its playable source.
    final resolved = items.where((i) => i.source.isNotEmpty).toList();
    var startId = items.isEmpty ? null : items[index.clamp(0, items.length - 1)].id;
    if (resolved.isEmpty) {
      lastError = 'No playable source found for this list';
      notifyListeners();
      await onError(lastError!);
      return;
    }
    queue = resolved;
    var start = resolved.indexWhere((e) => e.id == startId);
    if (start < 0) start = index.clamp(0, resolved.length - 1);
    currentIndex = start;
    notifyListeners();
    onPlayed(resolved[start]);

    try {
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: resolved.map(_sourceFor).toList()),
        initialIndex: start,
        initialPosition: Duration.zero,
      );
      _loaded = true;
      _pendingPos = Duration.zero;
    } catch (e) {
      if (_benignLoadError(e)) return; // a newer tap superseded this load
      // Fallback: load just the tapped track — isolates a bad queue member.
      try {
        await _player.setAudioSource(_sourceFor(resolved[start]));
        queue = [resolved[start]];
        currentIndex = 0;
        _loaded = true;
      } catch (e2) {
        if (_benignLoadError(e2)) return; // superseded again — stay quiet
        lastError = 'Playback failed: $e2';
        notifyListeners();
        await onError(lastError!);
        return;
      }
    }
    try {
      await _player.setSpeed(speed);
    } catch (_) {}
    // IMPORTANT: do not await play() — it completes only when playback ends.
    unawaited(_player.play().catchError((Object e) async {
      if (_benignLoadError(e)) return; // a newer load took over
      lastError = 'Playback failed: $e';
      notifyListeners();
      await onError(lastError!);
    }));
    notifyListeners();
  }

  Future<void> toggle() async {
    try {
      if (_player.playing) {
        await _player.pause();
        saveSession();
      } else {
        // Restored session whose engine load failed at startup:
        // load on demand at the saved position, then play.
        if (!_loaded && queue.isNotEmpty) await _loadCurrent();
        unawaited(_player.play());
      }
    } catch (e) {
      if (_benignLoadError(e)) return;
      lastError = 'Playback failed: $e';
      notifyListeners();
    }
  }

  Future<void> next() async => _player.seekToNext();
  Future<void> previous() async => _player.seekToPrevious();
  Future<void> seek(Duration d) async {
    await _player.seek(d);
    saveSession();
  }
  Future<void> stopAll() async {
    await _player.stop();
    queue = [];
    currentIndex = -1;
    _loaded = false;
    await _clearSession();
    notifyListeners();
  }

  LoopMode get loopMode => _player.loopMode;
  bool get shuffleOn => _player.shuffleModeEnabled;
  Future<void> cycleLoop() async {
    const modes = [LoopMode.off, LoopMode.all, LoopMode.one];
    final nxt = modes[(modes.indexOf(_player.loopMode) + 1) % modes.length];
    await _player.setLoopMode(nxt);
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    await _player.setShuffleModeEnabled(!_player.shuffleModeEnabled);
    if (_player.shuffleModeEnabled) await _player.shuffle();
    notifyListeners();
  }

  Future<void> setSpeed(double s) async {
    speed = s;
    await _player.setSpeed(s);
    notifyListeners();
  }

  Future<void> setVolume(double v) async => _player.setVolume(v.clamp(0, 1));

  void setSleepTimer(int? minutes) {
    _sleepTimer?.cancel();
    sleepMinutes = minutes;
    if (minutes != null) {
      _sleepTimer = Timer(Duration(minutes: minutes), () async {
        await _player.pause();
        sleepMinutes = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> crossfadeTo(Future<void> Function() action, double seconds) async {
    if (seconds <= 0) {
      await action();
      return;
    }
    const steps = 8;
    for (var i = steps; i >= 0; i--) {
      await _player.setVolume(i / steps);
      await Future.delayed(Duration(milliseconds: (seconds * 1000 / 2 / steps).round()));
    }
    await action();
    for (var i = 0; i <= steps; i++) {
      await _player.setVolume(i / steps);
      await Future.delayed(Duration(milliseconds: (seconds * 1000 / 2 / steps).round()));
    }
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _posSub?.cancel();
    _errSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}

/// EQ presets (gains in dB mapped onto each band's own min/max range in UI).

/// One queued play request (v2.26 load coalescing): while a load
/// is running, newer taps replace this instead of overlapping.
class _PendingPlay {
  _PendingPlay(this.items, this.index, this.onPlayed, this.onError);
  final List<m.MediaItem> items;
  final int index;
  final void Function(m.MediaItem) onPlayed;
  final Future<void> Function(String msg) onError;
}
