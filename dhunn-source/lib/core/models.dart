/// Core data models for NOVA PLAYER.
enum MediaKind { audio, video, stream, radio, podcastEpisode }

class MediaItem {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String source; // file path, content:// URI or URL (used for playback)
  final String filePath; // real filesystem path when known (converter/tools)
  final bool isLocal;
  final MediaKind kind;
  final String? artworkUrl; // network url or content:// uri or file path
  final Duration duration;
  final int sizeBytes;
  final String? lyrics;
  final String? feedUrl; // podcast feed for episodes
  final DateTime? dateAdded;

  const MediaItem({
    required this.id,
    required this.title,
    this.artist = '',
    this.album = '',
    required this.source,
    this.filePath = '',
    this.isLocal = false,
    this.kind = MediaKind.audio,
    this.artworkUrl,
    this.duration = Duration.zero,
    this.sizeBytes = 0,
    this.lyrics,
    this.feedUrl,
    this.dateAdded,
  });

  bool get isVideo =>
      kind == MediaKind.video ||
      RegExp(r'\.(mp4|mkv|webm|mov|m4v|3gp|ts|avi)$', caseSensitive: false)
          .hasMatch(source.split('?').first);
  bool get isStreamSource =>
      source.startsWith('http') &&
      (source.contains('.m3u8') || source.contains('.mpd'));

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'source': source,
        'filePath': filePath,
        'isLocal': isLocal,
        'kind': kind.index,
        'artworkUrl': artworkUrl,
        'durationMs': duration.inMilliseconds,
        'sizeBytes': sizeBytes,
        'lyrics': lyrics,
        'feedUrl': feedUrl,
        'dateAdded': dateAdded?.millisecondsSinceEpoch,
      };

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        id: j['id'] as String,
        title: j['title'] as String? ?? 'Unknown',
        artist: j['artist'] as String? ?? '',
        album: j['album'] as String? ?? '',
        source: j['source'] as String? ?? '',
        filePath: j['filePath'] as String? ?? '',
        isLocal: j['isLocal'] as bool? ?? false,
        kind: MediaKind.values[(j['kind'] as int?) ?? 0],
        artworkUrl: j['artworkUrl'] as String?,
        duration: Duration(milliseconds: (j['durationMs'] as int?) ?? 0),
        sizeBytes: (j['sizeBytes'] as int?) ?? 0,
        lyrics: j['lyrics'] as String?,
        feedUrl: j['feedUrl'] as String?,
        dateAdded: j['dateAdded'] != null
            ? DateTime.fromMillisecondsSinceEpoch(j['dateAdded'] as int)
            : null,
      );

  MediaItem copyWith({String? title, String? artist, String? album, String? lyrics, String? artworkUrl}) =>
      MediaItem(
        id: id, title: title ?? this.title, artist: artist ?? this.artist,
        album: album ?? this.album, source: source, filePath: filePath, isLocal: isLocal, kind: kind,
        artworkUrl: artworkUrl ?? this.artworkUrl, duration: duration, sizeBytes: sizeBytes,
        lyrics: lyrics ?? this.lyrics, feedUrl: feedUrl, dateAdded: dateAdded,
      );

  @override
  bool operator ==(Object other) => other is MediaItem && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class Playlist {
  final String id;
  String name;
  final List<String> itemIds;
  Playlist({required this.id, required this.name, List<String>? itemIds})
      : itemIds = itemIds ?? [];
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'itemIds': itemIds};
  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
      id: j['id'] as String,
      name: j['name'] as String? ?? 'Playlist',
      itemIds: ((j['itemIds'] as List?) ?? []).cast<String>());
}
