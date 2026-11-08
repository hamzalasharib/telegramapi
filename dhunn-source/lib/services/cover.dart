import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'net.dart';
import 'player.dart';
import 'notify.dart';

/// HD cover service (v2.8): when a song's cover is missing or only a
/// small thumbnail, fetch a HIGH-QUALITY cover automatically —
/// iTunes Search API first (artwork upgraded to 1200x1200), Deezer
/// second (cover_xl) — download it once via the native channel, save
/// it on the device and apply it everywhere (library, mini player,
/// Now Playing). A song is tried at most once a week on failure.
class CoverService {
  static const _ch = MethodChannel('nova/media');
  static final _inflight = <String>{};

  /// Returns true when a new HD cover was actually downloaded.
  /// [force] skips the once-a-week retry gate (manual bulk runs).
  static Future<bool> ensure(AppStore store, PlayerService? player, MediaItem item,
      {bool force = false}) async {
    if (!item.isLocal) return false;
    if (store.coverUpgrades.containsKey(item.id)) return false;
    if (_inflight.contains(item.id)) return false;
    if (!force) {
      final tried = store.coverTried[item.id];
      // v2.31: the retry gate was a WEEK, even for a momentary
      // network failure — one bad evening locked a song out of
      // auto covers for 7 days. A day is plenty.
      if (tried != null &&
          DateTime.now().millisecondsSinceEpoch - tried < 24 * 3600 * 1000) {
        return false;
      }
    }
    if (!await _needsUpgrade(item, _targetPx(store))) return false;
    _inflight.add(item.id);
    try {
      final hq = await _findHqUrl(item, _targetPx(store));
      if (hq == null) {
        store.markCoverTried(item.id);
        return false;
      }
      final name = 'cover_${item.id.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')}.jpg';
      final path = await _ch.invokeMethod<String>('downloadCover', {'url': hq, 'name': name});
      if (path == null) {
        store.markCoverTried(item.id);
        return false;
      }
      store.setCoverUpgrade(item.id, path);
      player?.updateArtwork(item.id, path);
      return true;
    } catch (_) {
      store.markCoverTried(item.id);
      return false;
    } finally {
      _inflight.remove(item.id);
    }
  }

  // ---- Bulk download (v2.10, Settings button) ----
  // v2.19: the job now (a) keeps running while the user leaves
  // Settings and uses the rest of the app, (b) posts a live progress
  // notification (native channel, no plugin), and (c) RESUMES where
  // it stopped — every processed song id is persisted, so a stopped
  // or killed job continues instead of starting over.
  static bool _bulkCancel = false;
  static bool _bulkRunning = false;
  static bool get bulkRunning => _bulkRunning;
  static void cancelBulk() => _bulkCancel = true;
  static const _notifyId = 7001;

  /// Walk the WHOLE library and download an HD cover for every song
  /// whose cover is missing or small. Returns (downloaded, total
  /// songs in the job). [onProgress] fires after each song with the
  /// JOB-WIDE numbers (resumed progress included).
  static Future<(int, int)> downloadAll(AppStore store, PlayerService? player,
      {void Function(int done, int total, int found)? onProgress}) async {
    if (_bulkRunning) return (store.coverBulkFound, store.coverBulkTotal);
    _bulkRunning = true;
    _bulkCancel = false;
    try {
      final all = <MediaItem>[];
      for (final item in store.localAudio) {
        if (store.coverUpgrades.containsKey(item.id)) continue;
        if (await _needsUpgrade(item, _targetPx(store))) all.add(item);
      }
      final doneIds = store.coverBulkDoneIds;
      if (all.isEmpty && doneIds.isEmpty) return (0, 0);
      final remaining = all.where((e) => !doneIds.contains(e.id)).toList();
      var total = store.coverBulkTotal;
      var found = store.coverBulkFound;
      if (doneIds.isEmpty || total <= 0) {
        total = all.length;
        found = 0;
        store.coverBulkTotal = total;
        store.coverBulkFound = 0;
        store.saveCoverBulk();
      }
      var done = doneIds.length;
      await ProgressNotify.progress(
          id: _notifyId,
          title: 'Downloading HD covers',
          text: '$done of $total songs',
          done: done,
          total: total);
      // Parallel pool (v2.22 speed fix): FIVE songs at a time and
      // NO artificial sleep between songs. The old version did
      // one song at a time with a 300 ms pause after each — with
      // two web searches per song that crawled even on fast net.
      var cursor = 0;
      var lastNotify = DateTime.now();
      Future<void> worker() async {
        while (!_bulkCancel) {
          final i = cursor++;
          if (i >= remaining.length) return;
          final item = remaining[i];
          if (await ensure(store, player, item, force: true)) found++;
          doneIds.add(item.id);
          done++;
          store.coverBulkFound = found;
          store.saveCoverBulk();
          onProgress?.call(done, total, found);
          final now = DateTime.now();
          if (now.difference(lastNotify).inMilliseconds > 1200 || done >= total) {
            lastNotify = now;
            await ProgressNotify.progress(
                id: _notifyId,
                title: 'Downloading HD covers',
                text: '$done of $total songs - $found downloaded',
                done: done,
                total: total);
          }
        }
      }
      await Future.wait([for (var w = 0; w < 5; w++) worker()]);
      if (_bulkCancel) {
        // Paused: state stays saved — the next tap RESUMES here.
        await ProgressNotify.done(
            id: _notifyId,
            title: 'HD covers paused',
            text: '$done of $total songs done - tap Download in Settings to resume');
      } else {
        store.coverBulkLastDone = done;
        store.coverBulkLastTotal = total;
        store.coverBulkLastFound = found;
        store.coverBulkLastAt = DateTime.now().millisecondsSinceEpoch;
        store.coverBulkDoneIds = {};
        store.coverBulkTotal = 0;
        store.coverBulkFound = 0;
        store.saveCoverBulk();
        await ProgressNotify.done(
            id: _notifyId,
            title: 'HD covers finished',
            text: '$found covers downloaded ($done songs checked)');
      }
      return (found, total);
    } finally {
      _bulkRunning = false;
    }
  }

  /// Background pass over songs with NO cover at all (e.g. after a
  /// fresh scan) — sequential and capped so it stays data-friendly.
  static Future<void> fillMissing(AppStore store, {int limit = 12}) async {
    var done = 0;
    for (final item in store.localAudio) {
      if (done >= limit) break;
      final noArt = item.artworkUrl == null || item.artworkUrl!.isEmpty;
      if (!noArt) continue;
      if (store.coverUpgrades.containsKey(item.id)) continue;
      await ensure(store, null, item);
      done++;
      await Future.delayed(const Duration(milliseconds: 60));
    }
  }

  static Future<bool> _needsUpgrade(MediaItem item, int targetPx) async {
    final url = item.artworkUrl;
    if (url == null || url.isEmpty) return true;
    if (url.startsWith('http')) return false;
    if (!url.startsWith('/')) return true;
    final f = File(url);
    if (!await f.exists()) return true;
    try {
      final bytes = await f.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      frame.image.dispose();
      codec.dispose();
      const minW = {512: 280, 800: 450, 1200: 500};
      return w < (minW[targetPx] ?? 500);
    } catch (_) {
      // v2.31: an unreadable/corrupt thumbnail used to mean
      // "never upgrade this song". Treat it as needing a cover.
      return true;
    }
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), ' ')
      .replaceAll(RegExp(r'feat\.?.*|ft\.?.*'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static double _sim(String a, String b) {
    final na = _norm(a), nb = _norm(b);
    if (na.isEmpty || nb.isEmpty) return 0;
    if (na == nb) return 1;
    if (na.contains(nb) || nb.contains(na)) return .85;
    final ta = na.split(' ').toSet(), tb = nb.split(' ').toSet();
    final inter = ta.intersection(tb).length;
    return inter / (ta.length > tb.length ? ta.length : tb.length);
  }

  static bool _match(MediaItem item, String candTitle, String candArtist) {
    final t = _sim(item.title, candTitle);
    if (t < .6) return false;
    if (item.artist.isEmpty || candArtist.isEmpty) return true;
    return _sim(item.artist, candArtist) >= .45;
  }

  static Future<(int, String)> _get(Uri u) =>
      Net.get(u, ua: 'HamzaPlayer/2.8 (Flutter)');

  /// Target cover size from the Album Art Resolution setting
  /// (v2.22): 0 Low = 512px (fastest), 1 Medium = 800px,
  /// 2 High = 1200px (best quality, the old behaviour).
  static int _targetPx(AppStore store) =>
      const [512, 800, 1200][store.coverRes.clamp(0, 2)];

  static Future<String?> _findHqUrl(MediaItem item, int px) async {
    // iTunes and Deezer run in PARALLEL (v2.22): the old code
    // waited for iTunes to miss before even asking Deezer, which
    // doubled the wait on every miss. iTunes still wins ties.
    final itunes = _fromItunes(item, px);
    final deezer = _fromDeezer(item, px);
    return (await itunes) ?? (await deezer);
  }

  /// Artist as it should appear in search queries: MediaStore
  /// junk ("<unknown>") is dropped entirely (v2.31).
  static String _qArtist(MediaItem item) {
    final a = item.artist.trim();
    if (a.isEmpty || a.toLowerCase() == '<unknown>' || a.toLowerCase() == 'unknown') {
      return '';
    }
    return a;
  }

  /// Shared result ladder (v2.31 cover fix). The old code took
  /// ONLY a strict title+artist similarity match, which rejected
  /// most of the user's real library (junk artist metadata alone
  /// sank it). The Java edition's near-100% hit rate comes from
  /// trusting the search ranking, so the ladder is now:
  ///   1. strict match (title + artist),
  ///   2. strong TITLE-only match (artist ignored),
  ///   3. the first result with artwork (search engines rank the
  ///      right release first for "title artist" queries).
  static String? _ladder(
      MediaItem item, List<(String, String, String)> rows) {
    for (final (t, a, art) in rows) {
      if (_match(item, t, a)) return art;
    }
    for (final (t, a, art) in rows) {
      if (_sim(item.title, t) >= .75) return art;
    }
    return rows.isEmpty ? null : rows.first.$3;
  }

  static Future<String?> _fromItunes(MediaItem item, int px) async {
    try {
      final artist = _qArtist(item);
      var term = '${item.title} $artist'.trim();
      for (var attempt = 0; attempt < 2; attempt++) {
        final u = Uri.https('itunes.apple.com', '/search',
            {'term': term, 'media': 'music', 'entity': 'song', 'limit': '8'});
        final (code, body) = await _get(u);
        if (code != 200) return null;
        final results = (jsonDecode(body)['results'] as List?) ?? [];
        final rows = <(String, String, String)>[
          for (final r in results)
            if ((r as Map<String, dynamic>)['artworkUrl100'] != null)
              (
                r['trackName'] as String? ?? '',
                r['artistName'] as String? ?? '',
                (r['artworkUrl100'] as String)
                    .replaceAll('100x100bb.jpg', '${px}x${px}bb.jpg'),
              ),
        ];
        final hit = _ladder(item, rows);
        if (hit != null) return hit;
        // No results at all: retry with the bare title.
        if (rows.isNotEmpty || artist.isEmpty) return null;
        term = item.title.trim();
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _fromDeezer(MediaItem item, int px) async {
    try {
      final artist = _qArtist(item);
      var q = '${item.title} $artist'.trim();
      final key = px <= 512 ? 'cover_big' : 'cover_xl';
      for (var attempt = 0; attempt < 2; attempt++) {
        final u = Uri.https('api.deezer.com', '/search', {'q': q, 'limit': '8'});
        final (code, body) = await _get(u);
        if (code != 200) return null;
        final data = (jsonDecode(body)['data'] as List?) ?? [];
        final rows = <(String, String, String)>[
          for (final r in data)
            if (((r as Map<String, dynamic>)['album']
                    as Map<String, dynamic>?)?[key]
                ?.isNotEmpty ??
                false)
              (
                r['title'] as String? ?? '',
                (r['artist'] as Map<String, dynamic>?)?['name'] as String? ?? '',
                ((r['album'] as Map<String, dynamic>)[key] as String),
              ),
        ];
        final hit = _ladder(item, rows);
        if (hit != null) return hit;
        if (rows.isNotEmpty || artist.isEmpty) return null;
        q = item.title.trim();
      }
    } catch (_) {}
    return null;
  }
}
