import 'package:flutter/material.dart' show Color, HSLColor;
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/store.dart';
import 'api.dart';
import 'dominant.dart';
import 'lyrics_fx.dart';
import 'player.dart';

/// Home-screen widget feed (v2.31): keeps the native Dhunn
/// player widget showing the current song — cover, title,
/// play state and the LIVE lyric line (it changes as the song
/// plays, exactly like the Now Playing lyrics view).
///
/// Lyrics resolve through the SAME order as the player:
/// the user's own lyrics -> embedded plain lyrics -> the
/// song's .lrc sidecar file -> the offline cache -> LRCLIB
/// (a fresh fetch is cached for next time). Pushes go over
/// the nova/widget channel and only happen when something
/// actually changed (new song, new line, play/pause flip).
class WidgetSync {
  static const _ch = MethodChannel('nova/widget');
  static bool _started = false;

  static AppStore? _store;
  static PlayerService? _player;
  static String _forId = '';
  static List<LrcLine>? _synced;
  static List<String> _plain = const [];
  static int _lineIdx = -2;
  static bool _playing = false;

  // Widget colours (v2.34, his request): the background follows
  // the playing cover's dominant colour (dark shade), and the
  // live lyric line wears the current lyrics-effect colour.
  static String _colorKey = '';
  static int _bgValue = 0xFF0D1512;
  static int _fxValue = 0;

  static void start(AppStore store, PlayerService player) {
    if (_started) return;
    _started = true;
    _store = store;
    _player = player;
    // Widget transport actions (v2.34): when the playback
    // service was dead, DhunnControlReceiver launched the app
    // with the tapped action; native pushes it here (warm) or
    // holds it for takeWidgetAction (cold start).
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'widgetAction') {
        await _applyAction(call.arguments as String? ?? '');
      }
      return null;
    });
    Future.delayed(const Duration(milliseconds: 700), () async {
      try {
        final pending =
            await _ch.invokeMethod<String>('takeWidgetAction');
        if (pending != null && pending.isNotEmpty) {
          await _applyAction(pending);
        }
      } catch (_) {}
    });
    player.addListener(_onPlayerEvent);
    player.player.positionStream.listen(_onPosition);
    player.player.playerStateStream.listen((st) {
      if (st.playing != _playing) {
        _playing = st.playing;
        _push();
      }
    });
    _playing = player.playing;
    _onPlayerEvent();
  }

  /// Perform a widget transport tap (v2.34). On the cold path
  /// the queue is empty (main() already restored the session,
  /// but if the app was warm with nothing queued, restore here
  /// too). Next/prev from a cold start also start playback —
  /// tapping the widget means "play my music".
  static Future<void> _applyAction(String action) async {
    final player = _player;
    final store = _store;
    if (player == null || store == null) return;
    try {
      final cold = player.queue.isEmpty;
      if (cold) await player.restoreSession(store.byId);
      if (player.queue.isEmpty) return;
      switch (action) {
        case 'next':
          await player.next();
          if (cold && !player.playing) await player.toggle();
          break;
        case 'prev':
          await player.previous();
          if (cold && !player.playing) await player.toggle();
          break;
        default: // play_pause
          await player.toggle();
      }
    } catch (_) {}
  }

  /// Resolve this song's widget colours (cover shade + effect
  /// colour) and re-push once they are known.
  static void _ensureColors(MediaItem item) {
    if (item.id == _colorKey) return;
    _colorKey = item.id;
    _bgValue = 0xFF0D1512;
    _fxValue = LyricsFx.of(_store?.lyricsStyle ?? 0)
        .colors(const Color(0xFF1DB954))
        .$1
        .value;
    DominantColor.of(item).then((dom) {
      if (_colorKey != item.id || dom == null) return;
      final hsl = HSLColor.fromColor(dom);
      _bgValue = hsl
          .withSaturation((hsl.saturation * 0.75).clamp(0.10, 0.55))
          .withLightness(0.13)
          .toColor()
          .value;
      _fxValue = LyricsFx.of(_store?.lyricsStyle ?? 0)
          .colors(vividAccent(dom))
          .$1
          .value;
      _push();
    });
  }

  static void _onPlayerEvent() {
    final item = _player?.current;
    if (item == null || item.id == _forId) return;
    _forId = item.id;
    _synced = null;
    _plain = const [];
    _lineIdx = -2;
    _ensureColors(item);
    _push();
    _resolve(item);
  }

  static Future<void> _resolve(MediaItem item) async {
    final store = _store!;
    try {
      final custom = store.customLyrics[item.id];
      if (custom != null && custom.trim().isNotEmpty) {
        _accept(item, custom);
        return;
      }
      if (item.lyrics != null && item.lyrics!.trim().isNotEmpty) {
        _accept(item, item.lyrics!);
        return;
      }
      final sidecar = await Api.sidecarLyrics(item);
      if (sidecar != null && (sidecar.plain != null || sidecar.hasSynced)) {
        if (_forId == item.id) {
          _synced = sidecar.synced;
          _plain = _plainOf(sidecar.plain);
          _afterLyrics();
        }
        return;
      }
      final cached = store.cachedLyricsRaw(item.id);
      if (cached != null) {
        final data = Api.dataFrom(plain: cached.$1, syncedRaw: cached.$2);
        if (_forId == item.id) {
          _synced = data.synced;
          _plain = _plainOf(data.plain);
          _afterLyrics();
        }
        return;
      }
      final data = await Api.fetchLyricsFull(item);
      if (data.plain != null || data.hasSynced) {
        store.saveLyricsCache(item.id,
            plain: data.plain, syncedRaw: data.rawSynced);
      }
      if (_forId == item.id) {
        _synced = data.synced;
        _plain = _plainOf(data.plain);
        _afterLyrics();
      }
    } catch (_) {
      // the widget simply shows no lyrics for this song
    }
  }

  static void _accept(MediaItem item, String raw) {
    if (_forId != item.id) return;
    final lines = Api.parseLrc(raw);
    if (lines.length > 1) {
      _synced = lines;
      _plain = const [];
    } else {
      _synced = null;
      _plain = _plainOf(raw);
    }
    _afterLyrics();
  }

  static List<String> _plainOf(String? plain) {
    if (plain == null) return const [];
    return plain
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static void _afterLyrics() {
    _lineIdx = -2;
    final pos = _player?.player.position ?? Duration.zero;
    _onPosition(pos);
    _push();
  }

  static void _onPosition(Duration pos) {
    final lines = _synced;
    if (lines == null || lines.isEmpty) return;
    var idx = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time <= pos) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx != _lineIdx) {
      _lineIdx = idx;
      _push();
    }
  }

  static void _push() {
    final item = _player?.current;
    if (item == null) return;
    var line = '';
    var next = '';
    final lines = _synced;
    if (lines != null && lines.isNotEmpty) {
      final idx = _lineIdx < 0 ? 0 : _lineIdx;
      if (idx < lines.length) line = lines[idx].text;
      if (idx + 1 < lines.length) next = lines[idx + 1].text;
    } else if (_plain.isNotEmpty) {
      line = _plain.first;
      if (_plain.length > 1) next = _plain[1];
    }
    final art = item.artworkUrl;
    _ensureColors(item);
    _ch.invokeMethod('update', {
      'title': item.title,
      'artist': item.artist,
      'line': line,
      'next': next,
      'art': (art != null && art.startsWith('/')) ? art : '',
      'playing': _playing,
      'color': _bgValue,
      'fx': _fxValue,
    }).catchError((_) => null);
  }
}
