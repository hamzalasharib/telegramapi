import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../services/player.dart';
import '../services/scanner.dart';
import 'widgets.dart';

enum LocalSort { title, artist, newest, duration }
enum LocalView { songs, albums, artists, folders }

/// Lyrics-tab ordering (v2.34, his request): ascending AND
/// descending choices, independent of the Songs tab sort.
enum LyricsSort { titleAsc, titleDesc, artistAsc, artistDesc, newest, oldest }

/// Library tab (Spotify-style): your device songs with Songs / Albums /
/// Artists / Folders views, plus Playlists, Liked Songs, History,
/// tabs.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  // local browser state
  String _q = '';
  LocalSort _sort = LocalSort.title;
  LyricsSort _lyricsSort = LyricsSort.titleAsc;
  LocalView _view = LocalView.songs;
  String? _drillTitle; // album/artist/folder drill-down
  List<MediaItem> _drillItems = [];
  bool _scanning = false;

  // Song locator (v2.33, his request): jump straight to the
  // currently playing song in the Songs list.
  final _songsScroll = ScrollController();
  final _qCtrl = TextEditingController();
  final _locateKey = GlobalKey();
  String? _targetId; // song the locator last jumped to
  String? _flashId; // song briefly highlighted after a jump

  @override
  void dispose() {
    _tabs.dispose();
    _songsScroll.dispose();
    _qCtrl.dispose();
    super.dispose();
  }

  /// Locate the playing song: reset any search/drill-down that
  /// could hide it, switch to the Songs view, scroll it into
  /// view and flash-highlight it.
  void _locateCurrent() {
    final player = context.read<PlayerService>();
    final cur = player.current;
    if (cur == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No song is playing right now')));
      return;
    }
    _tabs.animateTo(0);
    setState(() {
      _q = '';
      _qCtrl.clear();
      _view = LocalView.songs;
      _drillTitle = null;
      _drillItems = [];
      _targetId = cur.id;
      _flashId = cur.id;
    });
    _scrollToTarget(cur.id, 0);
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted && _flashId == cur.id) setState(() => _flashId = null);
    });
  }

  /// Scroll the Songs list to [id] — forcefully and exactly
  /// (v2.34 rework, his report: "click par zor se playing song
  /// par aajaye"). Rows have a fixed extent (72dp, see
  /// itemExtent on the list), so the target offset is exact
  /// math, never a guess. Retries across frames while the tab
  /// switch and list layout settle — the v2.33 version tried
  /// once, too early, and often landed nowhere.
  void _scrollToTarget(String id, int attempt) {
    if (!mounted || attempt > 14) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_songsScroll.hasClients) {
        _scrollToTarget(id, attempt + 1);
        return;
      }
      final items = _sorted(context.read<AppStore>().localAudio);
      final idx = items.indexWhere((e) => e.id == id);
      if (idx < 0) return;
      final pos = _songsScroll.position;
      final target = (idx * 72.0 - pos.viewportDimension * 0.30)
          .clamp(0.0, pos.maxScrollExtent);
      if ((pos.pixels - target).abs() < 4) {
        final ctx = _locateKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut, alignment: 0.30);
        }
        return;
      }
      _songsScroll
          .animateTo(target,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic)
          .whenComplete(() {
        if (!mounted) return;
        final ctx = _locateKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut, alignment: 0.30);
        }
      });
    });
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      var ok = await MediaScanner.ensurePermission();
      if (!ok) {
        ok = await Permission.audio.request().isGranted ||
            await Permission.storage.request().isGranted;
      }
      if (ok) {
        final (audio, _) = await MediaScanner.scan();
        if (mounted) {
          await context
              .read<AppStore>()
              .setLibrary(audio, const [], authoritative: true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    }
    if (mounted) setState(() => _scanning = false);
  }

  List<MediaItem> _sorted(List<MediaItem> src) {
    final list = [...src];
    switch (_sort) {
      case LocalSort.title: list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())); break;
      case LocalSort.artist: list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase())); break;
      case LocalSort.newest: list.sort((a, b) => (b.dateAdded ?? DateTime(0)).compareTo(a.dateAdded ?? DateTime(0))); break;
      case LocalSort.duration: list.sort((a, b) => b.duration.compareTo(a.duration)); break;
    }
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      return list.where((i) =>
          i.title.toLowerCase().contains(q) || i.artist.toLowerCase().contains(q) || i.album.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  String _folderOf(MediaItem i) {
    final p = i.filePath.isNotEmpty ? i.filePath : i.source;
    final parts = p.split('/');
    return parts.length > 1 ? parts[parts.length - 2] : 'Root';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final l = context.l;
    return Column(children: [
      TabBar(controller: _tabs, isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
        const Tab(text: 'Your Songs'),
        Tab(text: l.t('playlists')),
        const Tab(text: 'Liked'),
        const Tab(text: 'Lyrics'),
        Tab(text: l.t('history')),
      ]),
      Expanded(child: TabBarView(controller: _tabs, children: [
        _songsTab(store),
        _playlistTab(store),
        _favTab(store),
        _lyricsTab(store),
        _historyTab(store),
      ])),
    ]);
  }

  // ---------- Your Songs ----------
  Widget _songsTab(AppStore store) {
    final all = store.localAudio;
    if (_drillTitle != null) {
      return Column(children: [
        ListTile(
          leading: IconButton(icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() { _drillTitle = null; _drillItems = []; })),
          title: Text(_drillTitle!, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${_drillItems.length} songs'),
          trailing: IconButton(icon: const Icon(Icons.play_circle_fill, size: 34),
              color: Theme.of(context).colorScheme.primary,
              onPressed: () => playAudioList(context, _drillItems, 0)),
        ),
        Expanded(child: ListView.builder(itemCount: _drillItems.length,
            itemBuilder: (_, i) => TrackTile(item: _drillItems[i], list: _drillItems))),
      ]);
    }
    final items = _sorted(all);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _qCtrl,
            decoration: InputDecoration(
              hintText: 'Search your songs…', prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true, filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _q = v),
          )),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Go to playing song',
            onPressed: _locateCurrent,
          ),
          PopupMenuButton<LocalSort>(
            icon: const Icon(Icons.sort),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: LocalSort.title, child: Text('Title A–Z')),
              PopupMenuItem(value: LocalSort.artist, child: Text('Artist A–Z')),
              PopupMenuItem(value: LocalSort.newest, child: Text('Newest first')),
              PopupMenuItem(value: LocalSort.duration, child: Text('Longest first')),
            ],
          ),
          IconButton(
            icon: _scanning
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            tooltip: 'Scan device',
            onPressed: _scanning ? null : _scan,
          ),
        ]),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          for (final (v, label, icon) in [
            (LocalView.songs, 'Songs', Icons.music_note),
            (LocalView.albums, 'Albums', Icons.album),
            (LocalView.artists, 'Artists', Icons.person),
            (LocalView.folders, 'Folders', Icons.folder),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(icon, size: 16),
                label: Text(label),
                selected: _view == v,
                onSelected: (_) => setState(() => _view = v),
              ),
            ),
        ]),
      ),
      Expanded(child: _localBody(store, all, items)),
    ]);
  }

  Widget _localBody(AppStore store, List<MediaItem> all, List<MediaItem> items) {
    if (all.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.library_music_outlined, size: 52),
          const SizedBox(height: 12),
          const Text('No songs found yet. Tap scan to read music from this device.',
              textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: _scan, icon: const Icon(Icons.search), label: const Text('Scan device')),
        ]),
      ));
    }
    switch (_view) {
      case LocalView.songs:
        return ListView.builder(
            controller: _songsScroll,
            // Fixed row extent (TrackTile is a standard
            // title+subtitle ListTile): makes the song
            // locator's offset math EXACT (v2.34).
            itemExtent: 72,
            itemCount: items.length,
            itemBuilder: (_, i) {
              final it = items[i];
              Widget tile = TrackTile(item: it, list: items);
              if (it.id == _flashId) {
                tile = ColoredBox(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(.16),
                    child: tile);
              }
              if (it.id == _targetId) {
                tile = KeyedSubtree(key: _locateKey, child: tile);
              }
              return tile;
            });
      case LocalView.albums:
      case LocalView.artists:
      case LocalView.folders:
        final groups = <String, List<MediaItem>>{};
        for (final it in all) {
          final key = _view == LocalView.albums
              ? (it.album.isEmpty ? 'Unknown Album' : it.album)
              : _view == LocalView.artists
                  ? (it.artist.isEmpty ? 'Unknown Artist' : it.artist)
                  : _folderOf(it);
          groups.putIfAbsent(key, () => []).add(it);
        }
        final keys = groups.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        return ListView.builder(
          itemCount: keys.length,
          itemBuilder: (_, i) {
            final k = keys[i];
            final g = groups[k]!;
            return ListTile(
              leading: artwork(g.first, size: 48),
              title: Text(k, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${g.length} songs'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() { _drillTitle = k; _drillItems = _sorted(g); }),
            );
          },
        );
    }
  }

  // ---------- Liked ----------
  Widget _favTab(AppStore store) {
    final favs = store.favorites;
    if (favs.isEmpty) return const Center(child: Text('No liked songs yet — tap ♥ on any track.'));
    return ListView.builder(itemCount: favs.length,
        itemBuilder: (_, i) => TrackTile(item: favs[i], list: favs));
  }

  /// Lyrics-tab ordering (v2.34): ascending + descending.
  List<MediaItem> _sortLyrics(List<MediaItem> src) {
    final list = [...src];
    int byTitle(MediaItem a, MediaItem b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase());
    int byArtist(MediaItem a, MediaItem b) =>
        a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
    int byDate(MediaItem a, MediaItem b) =>
        (a.dateAdded ?? DateTime(0)).compareTo(b.dateAdded ?? DateTime(0));
    switch (_lyricsSort) {
      case LyricsSort.titleAsc: list.sort(byTitle); break;
      case LyricsSort.titleDesc: list.sort((a, b) => byTitle(b, a)); break;
      case LyricsSort.artistAsc: list.sort(byArtist); break;
      case LyricsSort.artistDesc: list.sort((a, b) => byArtist(b, a)); break;
      case LyricsSort.newest: list.sort((a, b) => byDate(b, a)); break;
      case LyricsSort.oldest: list.sort(byDate); break;
    }
    return list;
  }

  // ---------- With Lyrics (v2.33, his request) ----------
  /// Songs that already HAVE lyrics on this device: a .lrc file
  /// next to the song, lyrics the user saved/wrote, lyrics cached
  /// from LRCLIB, or lyrics embedded in the file itself.
  Widget _lyricsTab(AppStore store) {
    var items = store.localAudio
        .where((e) =>
            store.hasOfflineLyrics(e) ||
            (e.lyrics?.trim().isNotEmpty ?? false))
        .toList();
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      items = items
          .where((e) =>
              e.title.toLowerCase().contains(q) ||
              e.artist.toLowerCase().contains(q))
          .toList();
    }
    items = _sortLyrics(items);
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
              'No songs with lyrics yet.\n\nLyrics appear here when a song has a .lrc file beside it, lyrics you saved yourself, or synced lyrics fetched while playing. Tip: Settings → Downloads can fetch lyrics for the whole library at once.',
              textAlign: TextAlign.center),
        ),
      );
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
        child: Row(children: [
          const Icon(Icons.lyrics, size: 18),
          const SizedBox(width: 7),
          Text('${items.length} songs with lyrics',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          PopupMenuButton<LyricsSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort lyrics songs',
            onSelected: (v) => setState(() => _lyricsSort = v),
            itemBuilder: (_) => [
              for (final (v, label) in [
                (LyricsSort.titleAsc, 'Title A–Z'),
                (LyricsSort.titleDesc, 'Title Z–A'),
                (LyricsSort.artistAsc, 'Artist A–Z'),
                (LyricsSort.artistDesc, 'Artist Z–A'),
                (LyricsSort.newest, 'Newest first'),
                (LyricsSort.oldest, 'Oldest first'),
              ])
                PopupMenuItem(
                  value: v,
                  child: Row(children: [
                    Icon(Icons.check,
                        size: 16,
                        color: _lyricsSort == v
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent),
                    const SizedBox(width: 8),
                    Text(label),
                  ]),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill, size: 32),
            color: Theme.of(context).colorScheme.primary,
            tooltip: 'Play all',
            onPressed: () => playAudioList(context, items, 0),
          ),
        ]),
      ),
      Expanded(
          child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) =>
                  TrackTile(item: items[i], list: items))),
    ]);
  }

  // ---------- Playlists ----------
  Widget _playlistTab(AppStore store) {
    final smartRecent = [...store.localAudio]
      ..sort((a, b) => (b.dateAdded ?? DateTime(0)).compareTo(a.dateAdded ?? DateTime(0)));
    return ListView(children: [
      ListTile(
        leading: const CircleAvatar(child: Icon(Icons.auto_awesome)),
        title: const Text('Daily Mix (smart — most played + favorites)'),
        subtitle: Text('${store.mostPlayed.length} tracks'),
        trailing: const Icon(Icons.play_circle),
        onTap: () {
          final mix = {...store.mostPlayed, ...store.favorites}.toList();
          if (mix.isNotEmpty) playAudioList(context, mix, 0);
        },
      ),
      ListTile(
        leading: const CircleAvatar(child: Icon(Icons.schedule)),
        title: const Text('Recently Added (smart)'),
        subtitle: Text('${smartRecent.length} songs'),
        trailing: const Icon(Icons.play_circle),
        onTap: () {
          final aud = smartRecent.take(50).toList();
          if (aud.isNotEmpty) playAudioList(context, aud, 0);
        },
      ),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.add),
        title: Text(context.l.t('newPlaylist')),
        onTap: () async {
          final name = await askText(context, context.l.t('newPlaylist'), 'Playlist name');
          if (name != null && name.trim().isNotEmpty) store.createPlaylist(name.trim());
        },
      ),
      ...store.playlists.map((p) {
        final items = store.playlistItems(p);
        return ExpansionTile(
          leading: const Icon(Icons.queue_music),
          title: Text(p.name),
          subtitle: Text('${items.length} songs'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => store.deletePlaylist(p),
          ),
          children: items.map((it) => TrackTile(item: it, list: items)).toList(),
        );
      }),
    ]);
  }

  // ---------- History ----------
  Widget _historyTab(AppStore store) {
    final h = store.history;
    return Column(children: [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: store.clearHistory,
          icon: const Icon(Icons.delete_sweep, size: 18),
          label: Text(context.l.t('clearHistory')),
        ),
      ),
      Expanded(child: h.isEmpty
          ? const Center(child: Text('Nothing played yet.'))
          : ListView.builder(itemCount: h.length,
              itemBuilder: (_, i) => TrackTile(item: h[i], list: h))),
    ]);
  }
}
