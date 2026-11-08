import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/store.dart';
import 'widgets.dart';

/// Downloaded content (v2.24): shows exactly WHAT Dhunn has fetched
/// for the user — which songs got a new HD cover image (and when),
/// and which songs have lyrics saved offline. Opened from
/// Settings → My Library by tapping the summary tiles.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key, this.lyricsFirst = false});

  final bool lyricsFirst;

  static String _date(int ms) {
    if (ms <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    // Covers: newest first, resolved to songs that still exist.
    final coverIds = store.coverUpgrades.keys.toList()
      ..sort((a, b) => (store.coverUpgradeTimes[b] ?? 0)
          .compareTo(store.coverUpgradeTimes[a] ?? 0));
    final covers = coverIds.map(store.byId).whereType<MediaItem>().toList();

    // Lyrics: every song with offline lyrics (custom / .lrc file /
    // saved cache), with a small source label.
    String sourceOf(MediaItem e) {
      if (store.customLyrics.containsKey(e.id)) return 'Your lyrics';
      if (store.lyricsFileIds.contains(e.id)) return '.lrc file';
      return 'Saved';
    }

    final lyricSongs =
        store.localAudio.where(store.hasOfflineLyrics).toList();

    final coversSection = <Widget>[
      _header(context, Icons.image, 'HD covers downloaded',
          '${covers.length} songs got a new cover image'),
      if (covers.isEmpty)
        const ListTile(
            title: Text('No covers downloaded yet'),
            subtitle: Text(
                'When a song is missing a cover or has a small one, Dhunn fetches a high-quality image automatically')),
      for (final e in covers)
        ListTile(
          leading: artwork(e, size: 48, radius: 8),
          title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              '${e.artist}'
              '${_date(store.coverUpgradeTimes[e.id] ?? 0).isEmpty ? '' : ' • ${_date(store.coverUpgradeTimes[e.id] ?? 0)}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.hd, size: 18),
        ),
    ];

    final lyricsSection = <Widget>[
      _header(context, Icons.lyrics, 'Lyrics saved offline',
          '${lyricSongs.length} songs — these lyrics work without internet'),
      if (lyricSongs.isEmpty)
        const ListTile(
            title: Text('No lyrics saved yet'),
            subtitle: Text(
                'Play a song with internet once, or use "Download all lyrics" in Settings — the lyrics are then kept on the phone')),
      for (final e in lyricSongs)
        ListTile(
          leading: artwork(e, size: 48, radius: 8),
          title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${e.artist} • ${sourceOf(e)}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.lyrics, size: 18),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Downloaded covers & lyrics')),
      body: ListView(children: [
        ...(lyricsFirst
            ? [...lyricsSection, const Divider(), ...coversSection]
            : [...coversSection, const Divider(), ...lyricsSection]),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _header(
      BuildContext context, IconData icon, String title, String sub) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(children: [
        Icon(icon, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ),
      ]),
    );
  }
}
