import '../core/store.dart';
import 'api.dart';
import 'notify.dart';

/// One-tap OFFLINE lyrics download (v2.21, his request): walk the
/// whole library once and fetch every song's lyrics from LRCLIB,
/// saving them into the store's offline cache (lyricsCache). After
/// this job a song's lyrics open instantly with NO internet, the
/// same cache the player already reads first.
///
/// Mirrors the bulk HD-cover job: it keeps running while the user
/// uses the app, posts a live progress notification, and RESUMES
/// where it stopped — processed ids are persisted in the store.
class LyricsBulkService {
  static bool _running = false;
  static bool _cancel = false;
  static bool get running => _running;
  static void cancel() => _cancel = true;
  static const _notifyId = 7002;

  /// Returns (found, total): lyrics saved / songs in the job.
  static Future<(int, int)> downloadAll(AppStore store,
      {void Function(int done, int total, int found)? onProgress}) async {
    if (_running) return (store.lyricsBulkFound, store.lyricsBulkTotal);
    _running = true;
    _cancel = false;
    try {
      final todo = store.localAudio
          .where((e) =>
              store.cachedLyricsRaw(e.id) == null &&
              !store.customLyrics.containsKey(e.id))
          .toList();
      final doneIds = store.lyricsBulkDoneIds;
      var total = store.lyricsBulkTotal;
      var found = store.lyricsBulkFound;
      if (doneIds.isEmpty || total <= 0) {
        total = todo.length;
        found = 0;
        store.lyricsBulkTotal = total;
        store.lyricsBulkFound = 0;
        store.save();
      }
      final remaining = todo.where((e) => !doneIds.contains(e.id)).toList();
      // v2.31: `done` counts every song CHECKED this run, while
      // doneIds only gains songs whose lyrics were actually FOUND
      // — the old code marked misses as done too, so a paused job
      // never retried the songs it had failed on.
      var done = doneIds.length;
      if (total == 0) return (0, 0);
      await ProgressNotify.progress(
          id: _notifyId,
          title: 'Downloading lyrics for offline use',
          text: '$done of $total songs',
          done: done,
          total: total);
      // Parallel pool (v2.22 speed fix): SIX songs at a time, no
      // artificial sleep. The old version fetched one song at a
      // time with a 250 ms pause after each, so a big library
      // took forever even on a fast connection.
      var cursor = 0;
      var lastNotify = DateTime.now();
      Future<void> worker() async {
        while (!_cancel) {
          final i = cursor++;
          if (i >= remaining.length) return;
          final item = remaining[i];
          try {
            final data = await Api.fetchLyricsFull(item);
            if (data.plain != null || data.rawSynced != null) {
              store.saveLyricsCache(item.id,
                  plain: data.plain, syncedRaw: data.rawSynced);
              found++;
              doneIds.add(item.id); // only FOUND songs count as done
            }
          } catch (_) {
            // one bad lookup must not stop the whole job
          }
          done++;
          store.lyricsBulkFound = found;
          store.save();
          onProgress?.call(done, total, found);
          final now = DateTime.now();
          if (now.difference(lastNotify).inMilliseconds > 1200 || done >= total) {
            lastNotify = now;
            await ProgressNotify.progress(
                id: _notifyId,
                title: 'Downloading lyrics for offline use',
                text: '$done of $total songs — $found saved offline',
                done: done,
                total: total);
          }
        }
      }
      await Future.wait([for (var w = 0; w < 6; w++) worker()]);
      if (_cancel) {
        await ProgressNotify.done(
            id: _notifyId,
            title: 'Lyrics download paused',
            text:
                '$done of $total songs done — tap Download lyrics in Settings to resume');
      } else {
        store.lyricsBulkLastFound = found;
        store.lyricsBulkLastTotal = total;
        store.lyricsBulkDoneIds = {};
        store.lyricsBulkTotal = 0;
        store.lyricsBulkFound = 0;
        store.save();
        await ProgressNotify.done(
            id: _notifyId,
            title: 'Lyrics download finished',
            text: '$found lyrics saved offline ($total songs checked)');
      }
      return (found, total);
    } finally {
      _running = false;
    }
  }
}
