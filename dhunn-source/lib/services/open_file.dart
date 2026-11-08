import 'package:flutter/services.dart';
import '../core/models.dart';

/// Songs opened from a FILE MANAGER (v2.21, his request): the
/// manifest declares an audio VIEW intent-filter, so Dhunn shows
/// up in Android's "Open with" player picker. MainActivity keeps
/// the incoming intent (first launch AND onNewIntent) and hands
/// its metadata over the `nova/openfile` channel; this service
/// polls it and turns it into a playable MediaItem once per URI.
class OpenedFileService {
  static const _ch = MethodChannel('nova/openfile');
  static final _handled = <String>{};

  /// The song the user just opened from another app, or null.
  /// Each URI is returned only once per app run.
  static Future<MediaItem?> take() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('takeOpened');
      if (m == null) return null;
      final source = (m['source'] as String?) ?? '';
      if (source.isEmpty || _handled.contains(source)) return null;
      _handled.add(source);
      var title = (m['title'] as String?) ?? '';
      if (title.isEmpty) {
        title = source.split('/').last;
        final dot = title.lastIndexOf('.');
        if (dot > 0) title = title.substring(0, dot);
      }
      return MediaItem(
        id: 'opened_${source.hashCode}',
        title: title,
        artist: (m['artist'] as String?) ?? '',
        album: '',
        source: source,
        filePath: (m['path'] as String?) ?? '',
        isLocal: true,
        kind: MediaKind.audio,
        duration: Duration(milliseconds: (m['duration'] as int?) ?? 0),
      );
    } catch (_) {
      return null;
    }
  }
}
