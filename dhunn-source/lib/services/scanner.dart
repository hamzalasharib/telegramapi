import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/models.dart';

/// Local media scanning.
/// Primary route: native MediaStore query (MainActivity.kt, channel
/// `nova/media`) — fast, returns title/artist/album/duration/album-art.
/// Fallback: recursive file walk of common storage roots (also used on
/// non-Android platforms).
class MediaScanner {
  static const _ch = MethodChannel('nova/media');

  /// True when the last scan() really came from MediaStore.
  /// False means the degraded file-walk fallback produced the
  /// result (no artist/album/artwork, different ids) — auto
  /// refresh passes must NOT persist those over a healthy
  /// MediaStore library (v2.32 songs-vanish fix).
  static bool lastNativeOk = false;
  static const _audioExts = {
    '.mp3', '.aac', '.flac', '.wav', '.ogg', '.m4a', '.opus', '.wma', '.amr'
  };
  static const _videoExts = {
    '.mp4', '.mkv', '.avi', '.mov', '.flv', '.webm', '.m4v', '.3gp', '.mpg', '.mpeg', '.ts'
  };

  static Future<bool> ensurePermission() async {
    if (!Platform.isAndroid) return true;
    // Android 13+: granular media permissions; older: storage.
    final audio = await Permission.audio.request();
    final video = await Permission.videos.request();
    if (audio.isGranted || video.isGranted) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  static Future<(List<MediaItem>, List<MediaItem>)> scan() async {
    lastNativeOk = false;
    try {
      final res = await _ch.invokeMapMethod<String, dynamic>('scanMedia');
      if (res != null) {
        final audio = ((res['audio'] as List?) ?? [])
            .map((e) => _fromNative((e as Map).cast<String, dynamic>(), MediaKind.audio))
            .toList();
        final video = ((res['video'] as List?) ?? [])
            .map((e) => _fromNative((e as Map).cast<String, dynamic>(), MediaKind.video))
            .toList();
        if (audio.isNotEmpty || video.isNotEmpty) {
          lastNativeOk = true;
          return (audio, video);
        }
      }
    } on MissingPluginException {
      // fall through to file walk
    } on PlatformException {
      // fall through to file walk
    }
    return _walkFiles();
  }

  static MediaItem _fromNative(Map<String, dynamic> m, MediaKind kind) => MediaItem(
        id: 'local_${m['id']}',
        title: m['title'] as String? ?? 'Unknown',
        artist: m['artist'] as String? ?? '',
        album: m['album'] as String? ?? '',
        // Audio plays most reliably from its MediaStore content URI under
        // scoped storage; video keeps the real path (libmpv opens files and
        // the converter/status tools need real paths too).
        source: kind == MediaKind.audio
            ? (m['uri'] as String? ?? m['path'] as String? ?? '')
            : (m['path'] as String? ?? ''),
        filePath: m['path'] as String? ?? '',
        isLocal: true,
        kind: kind,
        // Prefer the cached thumbnail FILE (renderable by Image.file);
        // raw content:// art URIs can't be drawn by Flutter widgets.
        artworkUrl: (m['thumb'] as String?) ?? m['artUri'] as String?,
        duration: Duration(milliseconds: (m['duration'] as int?) ?? 0),
        sizeBytes: (m['size'] as int?) ?? 0,
        dateAdded: m['dateAdded'] != null
            ? DateTime.fromMillisecondsSinceEpoch((m['dateAdded'] as int) * 1000)
            : null,
      );

  static Future<(List<MediaItem>, List<MediaItem>)> _walkFiles() async {
    final audio = <MediaItem>[];
    final video = <MediaItem>[];
    final roots = <Directory>[
      Directory('/storage/emulated/0'),
      Directory('/sdcard'),
    ];
    final seen = <String>{};
    for (final root in roots) {
      if (!await root.exists() || seen.contains(root.path)) continue;
      seen.add(root.path);
      try {
        await for (final e in root.list(recursive: true, followLinks: false)) {
          if (e is! File) continue;
          final lower = e.path.toLowerCase();
          final ext = lower.contains('.') ? lower.substring(lower.lastIndexOf('.')) : '';
          final name = e.path.split('/').last;
          if (_audioExts.contains(ext)) {
            audio.add(MediaItem(
                id: 'file_${e.path.hashCode}', title: name.replaceAll(RegExp(r'\.[^.]+$'), ''),
                source: e.path, filePath: e.path, isLocal: true, kind: MediaKind.audio,
                sizeBytes: await e.length().catchError((_) => 0)));
          } else if (_videoExts.contains(ext)) {
            video.add(MediaItem(
                id: 'file_${e.path.hashCode}', title: name.replaceAll(RegExp(r'\.[^.]+$'), ''),
                source: e.path, filePath: e.path, isLocal: true, kind: MediaKind.video,
                sizeBytes: await e.length().catchError((_) => 0)));
          }
          if (audio.length + video.length > 5000) break;
        }
      } catch (_) {
        // unreadable root (permission) — skip silently
      }
    }
    audio.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    video.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return (audio, video);
  }
}
