import 'dart:convert';
import 'dart:io';
import '../core/models.dart';
import 'net.dart';

/// Hamza Player is an OFFLINE player: all songs come from the device.
/// The only network use is LRCLIB (free) for plain + SYNCED lyrics.
class Api {
  // dart:io HttpClient instead of package:http (size diet — one less
  // package in the snapshot for a single GET endpoint).
  static Future<(int, String)> _get(Uri u) =>
      Net.get(u, ua: 'HamzaPlayer/2.8 (Flutter; contact: user-owned app)');

  /// OFFLINE FIRST (v2.23): the song's own .lrc lyrics FILE
  /// sitting next to the audio file (same folder, same name).
  /// Returns its lyrics, or null when there is no sidecar file —
  /// callers only go online after this comes back empty.
  static Future<LyricsData?> sidecarLyrics(MediaItem item) async {
    try {
      final p = item.filePath.isNotEmpty ? item.filePath : item.source;
      if (!p.startsWith('/')) return null;
      final dot = p.lastIndexOf('.');
      final slash = p.lastIndexOf('/');
      if (dot < 0 || dot < slash) return null;
      final f = File('${p.substring(0, dot)}.lrc');
      if (!await f.exists()) return null;
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return null;
      final lines = parseLrc(raw);
      if (lines.length > 1) {
        return LyricsData(
            plain: lines.map((l) => l.text).join('\n'),
            synced: lines,
            rawSynced: raw);
      }
      return LyricsData(plain: raw.trim());
    } catch (_) {
      return null;
    }
  }

  // ---------- Lyrics (LRCLIB, free) ----------
  static Future<String?> fetchLyrics(MediaItem item) async {
    final full = await fetchLyricsFull(item);
    return full.plain;
  }

  /// Clean a metadata field for LRCLIB: MediaStore junk like
  /// "<unknown>" becomes empty, and titles lose the bracket /
  /// "official video" decorations file names often carry — LRCLIB
  /// matches on clean song names (v2.31 lyrics fix).
  static String _cleanTitle(String s) {
    var t = s
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), ' ')
        .replaceAll(
            RegExp(r'\b(official\s*(music\s*)?video|official\s*audio|lyrics?\s*video|hd\s*video)\b',
                caseSensitive: false),
            ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return t.isEmpty ? s.trim() : t;
  }

  static String _cleanArtist(String s) {
    final t = s.trim();
    if (t.isEmpty || t.toLowerCase() == '<unknown>' || t.toLowerCase() == 'unknown') {
      return '';
    }
    return t;
  }

  /// Full lyrics payload: plain text + SYNCED (LRC) lines when LRCLIB has
  /// them. Synced lines drive the karaoke Now Playing lyrics view.
  ///
  /// v2.31 BUG FIX: the old code called /api/get WITHOUT the
  /// `duration` parameter — LRCLIB *requires* it and answered 400,
  /// so the exact-match path NEVER worked and everything depended
  /// on the weak search fallback. (The Java edition sent duration
  /// all along, which is why its lyrics "always" arrived.) Now:
  /// exact get WITH duration → search (synced hits first, like
  /// Java) → cleaned-title search → title-only search.
  static Future<LyricsData> fetchLyricsFull(MediaItem item) async {
    final title = _cleanTitle(item.title);
    final artist = _cleanArtist(item.artist);
    try {
      final params = <String, String>{
        'track_name': title,
        'artist_name': artist,
        'duration': '${item.duration.inSeconds}',
      };
      if (item.album.trim().isNotEmpty &&
          item.album.trim().toLowerCase() != '<unknown>') {
        params['album_name'] = item.album.trim();
      }
      final u = Uri.https('lrclib.net', '/api/get', params);
      final (code, body) = await _get(u);
      if (code == 200) {
        final j = jsonDecode(body) as Map<String, dynamic>;
        final data = dataFrom(
            plain: j['plainLyrics'] as String?,
            syncedRaw: j['syncedLyrics'] as String?);
        if (data.plain != null || data.hasSynced) return data;
      }
    } catch (_) {}
    return _searchFallback(item, title, artist);
  }

  /// Search ladder: (1) title + artist, (2) title only when the
  /// artist is junk/absent, (3) the raw (uncleaned) title as a
  /// last resort. Each list is scanned SYNCED-first (the Java
  /// order), then plain — a karaoke hit beats a plain one.
  static Future<LyricsData> _searchFallback(
      MediaItem item, String title, String artist) async {
    final attempts = <Map<String, String>>[
      {'track_name': title, 'artist_name': artist},
      {'q': title},
      if (title != item.title.trim()) {'track_name': item.title.trim()},
    ];
    for (final params in attempts) {
      try {
        final u = Uri.https('lrclib.net', '/api/search', params);
        final (code, body) = await _get(u);
        if (code != 200) continue;
        final hits = jsonDecode(body) as List<dynamic>;
        for (final wantSynced in [true, false]) {
          for (final h in hits) {
            final m = h as Map<String, dynamic>;
            if (m['instrumental'] == true) continue;
            final syncedRaw = (m['syncedLyrics'] as String?)?.trim();
            final plain = (m['plainLyrics'] as String?)?.trim();
            if (wantSynced) {
              if (syncedRaw != null && syncedRaw.isNotEmpty) {
                return dataFrom(plain: plain, syncedRaw: syncedRaw);
              }
            } else if (plain != null && plain.isNotEmpty) {
              return dataFrom(plain: plain, syncedRaw: syncedRaw);
            }
          }
        }
      } catch (_) {}
    }
    return const LyricsData();
  }

  /// Build a LyricsData from LRCLIB-shaped fields. Keeps the RAW
  /// synced text so callers can cache it offline (v2.7) and rebuild
  /// the exact same timed lines later without the network.
  static LyricsData dataFrom({String? plain, String? syncedRaw}) {
    final synced = (syncedRaw == null || syncedRaw.isEmpty) ? null : parseLrc(syncedRaw);
    final p = (plain != null && plain.trim().isNotEmpty)
        ? plain.trim()
        : (synced != null ? synced.map((l) => l.text).join('\n') : null);
    return LyricsData(
      plain: p,
      synced: (synced != null && synced.length > 1) ? synced : null,
      rawSynced: syncedRaw,
    );
  }

  /// Parse LRC text ([mm:ss.xx] line) into timed lines.
  static List<LrcLine> parseLrc(String raw) {
    final out = <LrcLine>[];
    final re = RegExp(r'\[(\d+):(\d+)\.(\d+)\]\s?(.*)');
    for (final line in raw.split('\n')) {
      final m = re.firstMatch(line.trim());
      if (m == null) continue;
      final t = Duration(
        minutes: int.parse(m.group(1)!),
        seconds: int.parse(m.group(2)!),
        milliseconds: int.parse(m.group(3)!.padRight(3, '0').substring(0, 3)),
      );
      final text = m.group(4)!.trim();
      out.add(LrcLine(t, text));
    }
    out.sort((a, b) => a.time.compareTo(b.time));
    return out;
  }
}

class LrcLine {
  final Duration time;
  final String text;
  const LrcLine(this.time, this.text);
}

class LyricsData {
  final String? plain;
  final List<LrcLine>? synced;
  final String? rawSynced; // original LRC text, for the offline cache
  const LyricsData({this.plain, this.synced, this.rawSynced});
  bool get hasSynced => synced != null && synced!.isNotEmpty;
}
