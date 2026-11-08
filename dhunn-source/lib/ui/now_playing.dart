import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../core/l10n.dart';
import '../core/lyrics_fonts.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../services/api.dart';
import '../services/bg.dart';
import '../services/dominant.dart';
import '../services/cover.dart';
import '../services/eq.dart';
import '../services/lyrics_fx.dart';
import '../services/player.dart';
import 'connect_sheet.dart';
import 'drive_mode.dart';
import 'lyrics_editor.dart';
import 'lyrics_effects.dart';
import 'artwork_styles.dart';
import 'art_styles.dart';
import 'seek_bar.dart';
import 'widgets.dart';
import 'fluid_bg.dart';

/// Now Playing — Spotify-style layout (v2.1): top context bar, big
/// artwork, left-aligned title + heart, thin seek, big controls,
/// actions row and a live LYRICS CARD under the controls. Synced
/// lyrics (LRCLIB) auto-load per track; effects are switchable from
/// inside the player — no trip to Settings needed.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});
  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
  LyricsData? _lyricsData;
  bool _showLyrics = false;
  String? _lyricsForId;
  bool _lyricsLoading = false;
  bool _lyricsMiss = false; // fetched, nothing found
  bool _lyricsFromCache = false; // served from the offline cache

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  int _lyricsRevisionSeen = -1;
  String? _coverForId;
  Color? _domColor;
  String? _domForId;

  /// Glass tint: dominant colour of the current cover (auto-picked),
  /// falling back to the theme accent.
  Color _glassTint(MediaItem item, Color accent) {
    if (_domForId != item.id) {
      _domForId = item.id;
      _domColor = null;
      DominantColor.of(item).then((c) {
        if (mounted && _domForId == item.id) setState(() => _domColor = c);
      });
    }
    return _domColor ?? accent;
  }


  Future<void> _fetchLyrics(MediaItem item, {bool show = false}) async {
    if (_lyricsLoading) return;
    setState(() { _lyricsLoading = true; if (show) _showLyrics = true; });
    final store = context.read<AppStore>();
    final custom = store.customLyrics[item.id];
    // Offline file FIRST (v2.23): a .lrc file next to the song
    // loads instantly; online fetch is only the last resort.
    final sidecar = (custom == null || custom.trim().isEmpty)
        ? await Api.sidecarLyrics(item)
        : null;
    LyricsData data;
    var fromCache = false;
    if (sidecar != null) {
      data = sidecar;
      fromCache = true;
    } else if (custom != null && custom.trim().isNotEmpty) {
      final lines = Api.parseLrc(custom);
      data = lines.length > 1
          ? LyricsData(plain: lines.map((l) => l.text).join('\n'), synced: lines)
          : LyricsData(plain: custom.trim());
    } else if (item.lyrics != null) {
      data = LyricsData(plain: item.lyrics);
    } else if (store.cachedLyricsRaw(item.id) != null) {
      // Offline cache (v2.7): lyrics fetched once are saved on the
      // device and applied instantly — no network needed again.
      final c = store.cachedLyricsRaw(item.id)!;
      data = Api.dataFrom(plain: c.$1, syncedRaw: c.$2);
      fromCache = true;
    } else {
      data = await Api.fetchLyricsFull(item);
      // Auto-save whatever came from online for offline reuse.
      if (data.plain != null || data.hasSynced) {
        store.saveLyricsCache(item.id, plain: data.plain, syncedRaw: data.rawSynced);
      }
    }
    if (mounted) {
      setState(() {
        _lyricsData = data;
        _lyricsForId = item.id;
        _lyricsFromCache = fromCache;
        _lyricsRevisionSeen = context.read<AppStore>().lyricsRevision;
        _lyricsMiss = data.plain == null && !data.hasSynced;
        _lyricsLoading = false;
      });
    }
  }

  void _onLyricsChip(MediaItem item) {
    if (_showLyrics) {
      setState(() => _showLyrics = false);
    } else if (_lyricsForId == item.id && _lyricsData != null) {
      setState(() => _showLyrics = true);
    } else {
      _fetchLyrics(item, show: true);
    }
  }

  Widget _backdropFor(MediaItem item, AppStore store, Color accent, bool playing) {
    // User's own background picture wins over every effect.
    final bgPath = store.bgImagePath;
    if (bgPath != null && bgPath.isNotEmpty) {
      Widget img = Image.file(File(bgPath), fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _backdrop(item));
      if (store.bgImageBlur) {
        img = ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Transform.scale(scale: 1.2, child: img),
        );
      }
      return Stack(fit: StackFit.expand, children: [
        img,
        Container(color: Colors.black.withOpacity(store.bgImageBlur ? .45 : .30)),
      ]);
    }
    switch (store.bgEffect) {
      case 3: // Fluid Beat: liquid blobs in the COVER's colours,
        // pulsing on the real beat of the playing audio (v2.12).
        return FluidBeatBg(
            item: item,
            accent: accent,
            playing: playing,
            player: context.read<PlayerService>());
      case 1:
        return AnimatedBuilder(
          animation: _spin,
          builder: (_, __) {
            final hsl = HSLColor.fromColor(accent);
            final h1 = hsl.withHue((hsl.hue + _spin.value * 40) % 360).toColor();
            return Container(decoration: BoxDecoration(gradient: LinearGradient(
              colors: [h1.withOpacity(.55), const Color(0xFF0B0B14), accent.withOpacity(.25)],
              begin: Alignment.topLeft, end: Alignment.bottomRight)));
          },
        );
      case 2:
        return Container(color: const Color(0xFF0B0B14));
      default:
        return _backdrop(item);
    }
  }

  Widget _backdrop(MediaItem item) {
    final url = item.artworkUrl;
    Widget? img;
    if (url != null && url.startsWith('http')) {
      img = Image.network(url, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink());
    } else if (url != null && url.startsWith('/')) {
      img = Image.file(File(url), fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink());
    }
    return Stack(fit: StackFit.expand, children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF12351F), Color(0xFF0B0B14), Color(0xFF0A1F14)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
      ),
      if (img != null)
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
          child: Transform.scale(scale: 1.25, child: img),
        ),
      Container(color: Colors.black.withOpacity(.48)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final store = context.watch<AppStore>();
    final l = context.l;
    final item = player.current;
    if (item == null) {
      return Scaffold(appBar: AppBar(title: Text(l.t('nowPlaying'))),
          body: Center(child: Text(l.t('noResults'))));
    }
    // Custom lyrics changed in the editor → reload for this track.
    if (_lyricsForId == item.id &&
        _lyricsRevisionSeen != store.lyricsRevision &&
        !_lyricsLoading) {
      _lyricsForId = null;
      _lyricsData = null;
    }
    // Auto-load lyrics for the current track (Spotify behaviour).
    if (item.id != _lyricsForId && !_lyricsLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && player.current?.id == item.id) _fetchLyrics(item);
      });
    }
    // Auto-fetch an HD cover if this song's art is missing/low-res.
    if (item.id != _coverForId) {
      _coverForId = item.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CoverService.ensure(store, player, item);
      });
    }
    if (!player.playing) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
    final accent = Theme.of(context).colorScheme.primary;
    final nextItem = (player.currentIndex >= 0 &&
            player.currentIndex + 1 < player.queue.length)
        ? player.queue[player.currentIndex + 1]
        : null;
    final size = MediaQuery.of(context).size;
    final art = (size.width - 48).clamp(240.0, 360.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black45,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0x8A000000),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(children: [
          const Text('PLAYING FROM',
              style: TextStyle(color: Colors.white54, fontSize: 9.5, letterSpacing: 1.6)),
          Text(item.album.isEmpty ? 'Your Library' : item.album,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
        centerTitle: true,
        actions: [
          IconButton(
              tooltip: 'Connect device',
              icon: const Icon(Icons.devices, color: Colors.white),
              onPressed: () => showConnectSheet(context)),
          IconButton(
              tooltip: 'Album art style',
              icon: const Icon(Icons.style_outlined, color: Colors.white),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ArtStylesScreen()))),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () => showItemMenu(context, item)),
        ],
      ),
      body: Stack(fit: StackFit.expand, children: [
        _backdropFor(item, store, accent, player.playing),
        // top shade: status-bar area always dark & readable
        Positioned(
          top: 0, left: 0, right: 0, height: 110,
          child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent]))),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              const SizedBox(height: 4),
              if (_showLyrics)
                Expanded(child: _lyricsPanel(context, item, player, accent, 0))
              else
                ArtworkView(item: item, style: store.playerStyle,
                    size: art, playing: player.playing, accent: accent,
                    rotateDisc: store.rotateDisc),
              const SizedBox(height: 18),
              // Spotify title row: left-aligned + heart
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(item.artist.isEmpty ? 'Unknown artist' : item.artist,
                      style: const TextStyle(fontSize: 14, color: Colors.white60),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                FavHeartButton(item: item),
              ]),
              StreamBuilder<Duration>(
                stream: player.player.positionStream,
                builder: (_, snap) {
                  final pos = snap.data ?? player.player.position;
                  final dur = player.player.duration ?? item.duration;
                  return Column(children: [
                    // v2.30: custom progress bar — 24 drawn designs
                    // (Settings -> Player & Lyrics, or long-press).
                    GestureDetector(
                      onLongPress: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const SeekStylesScreen())),
                      child: SeekBar(
                        progress: dur.inMilliseconds == 0
                            ? 0
                            : (pos.inMilliseconds / dur.inMilliseconds)
                                .clamp(0.0, 1.0),
                        accent: accent,
                        style: store.seekStyle,
                        onSeek: dur.inMilliseconds == 0
                            ? null
                            : (f) => player.seek(Duration(
                                milliseconds:
                                    (f * dur.inMilliseconds).round())),
                      ),
                    ),
                    Row(children: [
                      Text(formatDuration(pos), style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
                      const Spacer(),
                      Text(formatDuration(dur), style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
                    ]),
                  ]);
                },
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(
                  iconSize: 23,
                  icon: Icon(Icons.shuffle, color: player.shuffleOn ? accent : Colors.white60),
                  onPressed: player.toggleShuffle),
                IconButton(iconSize: 38, icon: const Icon(Icons.skip_previous_rounded, color: Colors.white), onPressed: player.previous),
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 8,
                  shadowColor: Colors.black54,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      if (store.haptics) HapticFeedback.lightImpact();
                      player.toggle();
                    },
                    child: SizedBox(
                      width: 74, height: 74,
                      child: Icon(player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 42, color: Colors.black),
                    ),
                  ),
                ),
                IconButton(iconSize: 38, icon: const Icon(Icons.skip_next_rounded, color: Colors.white), onPressed: player.next),
                IconButton(
                  iconSize: 23,
                  icon: Icon(
                    player.loopMode == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                    color: player.loopMode != LoopMode.off ? accent : Colors.white60),
                  onPressed: player.cycleLoop),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _chip(context, Icons.lyrics_outlined, l.t('lyrics'), () => _onLyricsChip(item),
                    active: _showLyrics),
                _chip(context, Icons.graphic_eq, l.t('equalizer'), () => _eqSheet(context, player)),
                _chip(context, Icons.timer_outlined,
                    player.sleepMinutes == null ? l.t('sleepTimer') : '${player.sleepMinutes} min',
                    () => _sleepSheet(context, player)),
                _chip(context, Icons.speed, '${player.speed}x', () => _speedSheet(context, player)),
                _chip(context, Icons.queue_music, l.t('queue'), () => _queueSheet(context, player)),
                _chip(context, Icons.directions_car, 'Drive', () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DriveModeScreen()))),
              ]),
              if (!_showLyrics)
                Expanded(child: _lyricsCard(context, item, player, accent)),
              const SizedBox(height: 10),
              if (nextItem != null)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => player.next(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.08),
                        borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      const Icon(Icons.skip_next, color: Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      const Text('Up next: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Expanded(child: Text(nextItem.title, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ]),
    ),
    );
  }

  Widget _lyricsPanel(BuildContext context, MediaItem item, PlayerService player,
      Color accent, double art) {
    final store = context.watch<AppStore>();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
      height: art == 0 ? null : art,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
            _glassTint(item, accent).withOpacity(.30), Colors.white.withOpacity(.05)),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.22)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 0),
          child: Row(children: [
            Icon(Icons.lyrics, color: accent, size: 18),
            const SizedBox(width: 6),
            Text(_lyricsData?.hasSynced == true
                ? (_lyricsFromCache ? 'Synced lyrics • Saved offline' : 'Synced lyrics • LRCLIB')
                : 'Lyrics',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              tooltip: 'Lyrics effects',
              icon: const Icon(Icons.auto_awesome, color: Colors.white70, size: 19),
              onPressed: () => showLyricsStyleSheet(context),
            ),
            IconButton(
              tooltip: 'Add / edit lyrics',
              icon: const Icon(Icons.edit_note, color: Colors.white70, size: 20),
              onPressed: () => showLyricsSourceSheet(context, item),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_full, color: Colors.white70, size: 19),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LyricsFullScreen(item: item))),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 19),
              onPressed: () => setState(() => _showLyrics = false),
            ),
          ]),
        ),
        Expanded(child: _lyricsLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : (_lyricsData?.hasSynced == true
                ? SyncedLyricsView(lines: _lyricsData!.synced!, player: player,
                    style: store.lyricsStyle, accent: accent, fontSize: 17,
                    blurScale: store.lyricsBlurScale, animate: store.animatedLyrics,
                    customColor: store.lyricsColorValue == 0 ? null : Color(store.lyricsColorValue),
                    fontFamily: LyricsFonts.familyOf(store.lyricsFont))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                        _lyricsMiss ? 'No lyrics found for this track.' : (_lyricsData?.plain ?? ''),
                        style: TextStyle(fontFamily: LyricsFonts.familyOf(store.lyricsFont),
                            height: 1.55, color: Colors.white, fontSize: 15))))),
      ]),
        ),
      ),
    );
  }

  /// Spotify-style lyrics card under the controls: current synced line
  /// big and clear, next line faint. Tap → full-screen lyrics.
  Widget _lyricsCard(BuildContext context, MediaItem item, PlayerService player, Color accent) {
    final lyricsFontFamily =
        LyricsFonts.familyOf(context.read<AppStore>().lyricsFont);
    if (_lyricsLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
          SizedBox(width: 8),
          Text('Loading lyrics…', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      );
    }
    final data = _lyricsData;
    if (_lyricsForId != item.id || data == null || _lyricsMiss) {
      return const SizedBox(height: 10);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => LyricsFullScreen(item: item))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
                _glassTint(item, accent).withOpacity(.34), Colors.white.withOpacity(.05)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.25)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: const [
              Text('Lyrics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              Spacer(),
              Icon(Icons.open_in_full, color: Colors.white70, size: 16),
            ]),
            const SizedBox(height: 8),
            if (data.hasSynced)
              StreamBuilder<Duration>(
                stream: player.player.positionStream,
                builder: (_, snap) {
                  final lines = data.synced!;
                  var idx = -1;
                  final pos = snap.data ?? player.player.position;
                  for (var i = 0; i < lines.length; i++) {
                    if (lines[i].time <= pos) {
                      idx = i;
                    } else {
                      break;
                    }
                  }
                  final cur = (idx >= 0 && lines[idx].text.isNotEmpty)
                      ? lines[idx].text
                      : (lines.isNotEmpty ? lines.first.text : '');
                  final next = (idx + 1 < lines.length) ? lines[idx + 1].text : '';
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(cur, key: ValueKey(cur),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: lyricsFontFamily, color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800, height: 1.3)),
                    ),
                    if (next.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(next, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: lyricsFontFamily, color: Colors.white60, fontSize: 13)),
                      ),
                  ]);
                },
              )
            else
              Text(data.plain ?? '', maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: lyricsFontFamily, color: Colors.white, fontSize: 14.5, height: 1.35)),
          ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext c, IconData icon, String label, VoidCallback onTap, {bool active = false}) => InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(children: [
            Icon(icon, size: 22, color: active ? Theme.of(c).colorScheme.primary : Colors.white),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11,
                color: active ? Theme.of(c).colorScheme.primary : Colors.white70)),
          ]),
        ),
      );

  void _speedSheet(BuildContext context, PlayerService player) {
    showModalBottomSheet(context: context, showDragHandle: true, builder: (_) =>
        Column(mainAxisSize: MainAxisSize.min, children: [
          for (final s in [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
            ListTile(
              title: Text('${s}x'), trailing: player.speed == s ? const Icon(Icons.check) : null,
              onTap: () { player.setSpeed(s); Navigator.pop(context); },
            ),
          const SizedBox(height: 8),
        ]));
  }

  void _sleepSheet(BuildContext context, PlayerService player) {
    showModalBottomSheet(context: context, showDragHandle: true, builder: (_) =>
        Column(mainAxisSize: MainAxisSize.min, children: [
          for (final m in [null, 5, 15, 30, 45, 60])
            ListTile(
              title: Text(m == null ? 'Off' : '$m minutes'),
              trailing: player.sleepMinutes == m ? const Icon(Icons.check) : null,
              onTap: () { player.setSleepTimer(m); Navigator.pop(context); },
            ),
          const SizedBox(height: 8),
        ]));
  }

  void _queueSheet(BuildContext context, PlayerService player) {
    showModalBottomSheet(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) =>
        SizedBox(height: MediaQuery.of(context).size.height * .6, child: ListView.builder(
          itemCount: player.queue.length,
          itemBuilder: (_, i) {
            final q = player.queue[i];
            return ListTile(
              leading: artwork(q, size: 42),
              title: Text(q.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(q.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: i == player.currentIndex ? const Icon(Icons.equalizer) : null,
              onTap: () async {
                await player.player.seek(Duration.zero, index: i);
                await player.player.play();
                if (context.mounted) Navigator.pop(context);
              },
            );
          },
        )));
  }

  void _eqSheet(BuildContext context, PlayerService player) {
    showModalBottomSheet(
      context: context, showDragHandle: true, isScrollControlled: true,
      builder: (_) => const EqSheet(),
    );
  }
}

/// Equalizer sheet — PixelPlayer-style layout (v2.22): preset
/// chips on top, tall VERTICAL band sliders in a card with the dB
/// value above and the frequency below, a Save button for named
/// CUSTOM presets, and three round knob cards (Bass Boost,
/// Virtualizer, Loudness) with % dials and on/off switches.
/// Everything drives the NATIVE audiofx session through
/// [EqService] — device band count and range are the device's own.
class EqSheet extends StatelessWidget {
  const EqSheet({super.key});

  String _dbTop(int mb) {
    final db = (mb / 100).round();
    return db > 0 ? '+$db' : '$db';
  }

  String _freqShort(int hz) {
    if (hz >= 1000) {
      final k = hz / 1000;
      return k == k.roundToDouble() ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
    }
    return '$hz';
  }

  Future<void> _saveCustom(BuildContext context, EqService eq) async {
    final name = await askText(context, 'Save custom preset', 'e.g. My Sound');
    if (name != null && name.trim().isNotEmpty) {
      await eq.saveCustomPreset(name.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Preset "${name.trim()}" saved ✓')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eq = EqService.instance;
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: eq,
      builder: (context, _) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * .84,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              const Expanded(child: Text('Equalizer',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
              IconButton(
                tooltip: eq.enabled ? 'Turn EQ off' : 'Turn EQ on',
                icon: Icon(Icons.power_settings_new,
                    color: eq.enabled ? cs.primary : Colors.grey),
                onPressed: () => eq.setEnabled(!eq.enabled),
              ),
              Switch(value: eq.enabled, onChanged: eq.setEnabled),
            ]),
            if (!eq.attached && !eq.failed)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('▶ Play any song first — the equalizer attaches to the playing track and then works live. Your settings are saved and auto-applied to every song.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey)),
              ),
            if (eq.failed)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('This device refused the audio effects. Try again while a song is playing; some Bluetooth routes block EQ.',
                    style: TextStyle(fontSize: 12.5, color: Colors.orange)),
              ),
            if (eq.attached) ...[
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final name in EqService.presets.keys)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(name.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          selected: eq.preset == name,
                          onSelected: eq.enabled ? (_) => eq.applyPreset(name) : null,
                        ),
                      ),
                    for (final name in eq.customPresets.keys)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onLongPress: eq.enabled
                              ? () async {
                                  final ok = await confirmDialog(context,
                                      'Delete preset', 'Remove "$name"?');
                                  if (ok) await eq.deleteCustomPreset(name);
                                }
                              : null,
                          child: ChoiceChip(
                            avatar: const Icon(Icons.star, size: 14),
                            label: Text(name.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            selected: eq.preset == name,
                            onSelected: eq.enabled ? (_) => eq.applyCustomPreset(name) : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(.45),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                          eq.preset == 'Custom' ? 'CUSTOM' : eq.preset.toUpperCase(),
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: cs.primary, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: eq.enabled ? () => _saveCustom(context, eq) : null,
                      icon: const Icon(Icons.save_outlined, size: 17),
                      label: const Text('Save'),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < eq.bandCount; i++)
                          SizedBox(
                            width: 56,
                            child: Column(children: [
                              Text(
                                  _dbTop(i < eq.gainsMb.length ? eq.gainsMb[i] : 0),
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                              SizedBox(
                                height: 178,
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: Slider(
                                    value: (i < eq.gainsMb.length ? eq.gainsMb[i] : 0)
                                        .clamp(eq.minMb, eq.maxMb).toDouble(),
                                    min: eq.minMb.toDouble(),
                                    max: eq.maxMb.toDouble(),
                                    onChanged: eq.enabled
                                        ? (v) => eq.setBand(i, v.round())
                                        : null,
                                  ),
                                ),
                              ),
                              Text(
                                  i < eq.freqsHz.length ? _freqShort(eq.freqsHz[i]) : '${i + 1}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ]),
                          ),
                      ],
                    ),
                  ),
                  Text('${eq.bandCount} bands • ${(eq.minMb / 100).toStringAsFixed(0)} to +${(eq.maxMb / 100).toStringAsFixed(0)} dB (device audio FX)',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _KnobCard(
                  title: 'Bass Boost',
                  fraction: eq.bass / 1000,
                  percent: (eq.bass / 10).round(),
                  on: eq.bassOn,
                  enabledAll: eq.enabled,
                  onDrag: (f) => eq.setBass((f * 1000).round()),
                  onToggle: (v) => eq.setKnobOn('bass', v),
                )),
                const SizedBox(width: 10),
                Expanded(child: _KnobCard(
                  title: 'Virtualizer',
                  fraction: eq.virt / 1000,
                  percent: (eq.virt / 10).round(),
                  on: eq.virtOn,
                  enabledAll: eq.enabled && eq.virtSupported,
                  disabledNote: eq.virtSupported ? null : 'Not on this device',
                  onDrag: (f) => eq.setVirt((f * 1000).round()),
                  onToggle: (v) => eq.setKnobOn('virt', v),
                )),
                const SizedBox(width: 10),
                Expanded(child: _KnobCard(
                  title: 'Loudness',
                  fraction: eq.loudMb / 1500,
                  percent: (eq.loudMb / 15).round(),
                  on: eq.loudOn,
                  enabledAll: eq.enabled,
                  onDrag: (f) => eq.setLoud((f * 1500).round()),
                  onToggle: (v) => eq.setKnobOn('loud', v),
                )),
              ]),
              const SizedBox(height: 8),
              const Text(
                  'Drag a dial up or down to change it. Native Android audio-FX on the player session — works with speakers, earphones and most Bluetooth devices.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
            const SizedBox(height: 12),
          ]),
        );
      },
    );
  }
}

/// Round % dial card (PixelPlayer-style knob): an arc showing the
/// value, the percent in the middle, a switch underneath and the
/// effect name. Drag vertically to change the value.
class _KnobCard extends StatelessWidget {
  final String title;
  final double fraction; // 0..1
  final int percent;
  final bool on;
  final bool enabledAll;
  final String? disabledNote;
  final ValueChanged<double> onDrag;
  final ValueChanged<bool> onToggle;
  const _KnobCard({
    required this.title,
    required this.fraction,
    required this.percent,
    required this.on,
    required this.enabledAll,
    required this.onDrag,
    required this.onToggle,
    this.disabledNote,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = enabledAll && on;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: [
        GestureDetector(
          onVerticalDragUpdate: enabledAll
              ? (d) => onDrag((fraction - d.delta.dy / 140).clamp(0.0, 1.0))
              : null,
          child: SizedBox(
            width: 84, height: 84,
            child: CustomPaint(
              painter: _KnobPainter(
                fraction: fraction.clamp(0.0, 1.0),
                color: active ? cs.primary : Colors.grey,
                track: cs.onSurface.withOpacity(.14),
              ),
              child: Center(child: Text('$percent%',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: active ? null : Colors.grey))),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Switch(value: on, onChanged: enabledAll ? onToggle : null),
        Text(title,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        if (disabledNote != null)
          Text(disabledNote!,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center),
      ]),
    );
  }
}

class _KnobPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color track;
  const _KnobPainter({required this.fraction, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const start = 2.35; // ~135 degrees
    const sweep = 3.93; // ~225 degrees of travel... extended below
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        start, 4.71, false, trackPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        start, 4.71 * fraction, false, valuePaint);
    final ang = start + 4.71 * fraction;
    final dot = Offset(
        center.dx + radius * cos(ang), center.dy + radius * sin(ang));
    canvas.drawCircle(dot, 7, Paint()..color = color);
    final _ = sweep;
  }

  @override
  bool shouldRepaint(_KnobPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// Lyrics effect picker — opens the full gallery (120 presets).
void showLyricsStyleSheet(BuildContext context) {
  Navigator.push(context,
      MaterialPageRoute(builder: (_) => const LyricsEffectsScreen()));
}

/// Synced lyrics list: FIXED row height so auto-scroll lands exactly
/// on the current line. Rendering is driven by the LyricsFx preset
/// engine (120 presets — see services/lyrics_fx.dart): blur, glow,
/// karaoke word-fill, typewriter, pill, wave, giant-center, neon…
class SyncedLyricsView extends StatefulWidget {
  final List<LrcLine> lines;
  final PlayerService player;
  final int style;
  final Color accent;
  final double fontSize;
  final double blurScale; // lyrics blur strength multiplier (v2.22)
  final bool animate; // Animated lyrics toggle (v2.22)
  final Color? customColor; // user's own lyrics colour (v2.27)
  final String? fontFamily; // user's lyrics font (v2.33); null = default
  const SyncedLyricsView({super.key, required this.lines, required this.player,
      required this.style, required this.accent, this.fontSize = 17,
      this.blurScale = 1.0, this.animate = true, this.customColor,
      this.fontFamily});
  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  final _scroll = ScrollController();
  int _current = -2;

  double get _extent => (widget.fontSize + 4) * 3.05;

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  int _indexFor(Duration pos) {
    var idx = -1;
    for (var i = 0; i < widget.lines.length; i++) {
      if (widget.lines[i].time <= pos) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  void _syncScroll(int idx) {
    if (idx == _current) return;
    _current = idx;
    if (idx < 0 || !_scroll.hasClients) return;
    final vp = _scroll.position.viewportDimension;
    final target = (idx * _extent - vp / 2 + _extent / 2)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    if (!widget.animate) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 480), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fx = LyricsFx.of(widget.style);
    return StreamBuilder<Duration>(
      stream: widget.player.player.positionStream,
      builder: (_, snap) {
        final pos = snap.data ?? widget.player.player.position;
        final idx = _indexFor(pos);
        WidgetsBinding.instance.addPostFrameCallback((_) => _syncScroll(idx));
        var progress = 0.0;
        if (idx >= 0) {
          final start = widget.lines[idx].time;
          final end = idx + 1 < widget.lines.length
              ? widget.lines[idx + 1].time
              : start + const Duration(seconds: 5);
          final span = (end - start).inMilliseconds;
          if (span > 0) {
            progress = ((pos - start).inMilliseconds / span).clamp(0.0, 1.0);
          }
        }
        return ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
            stops: [0, .06, .94, 1],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
          controller: _scroll,
          itemExtent: _extent,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          itemCount: widget.lines.length,
          itemBuilder: (_, i) {
            final line = widget.lines[i];
            return _line(line, i, i == idx, i < idx, i == idx ? progress : 0, fx);
          },
          ),
        );
      },
    );
  }

  Widget _line(LrcLine line, int i, bool active, bool past, double progress, LyricsFx fx) {
    final fs = widget.fontSize;
    var (c1, c2) = fx.colors(widget.accent);
    if (widget.customColor != null) {
      // Custom lyrics colour wins over the effect's colourway.
      c1 = widget.customColor!;
      c2 = Color.lerp(c1, Colors.white, .35)!;
    }
    final rawText = line.text.isEmpty ? '♪' : line.text;
    final idleStyle = TextStyle(
      fontFamily: widget.fontFamily,
      fontSize: fs * fx.idleScale,
      fontWeight: FontWeight.w600,
      color: Colors.white.withOpacity(past ? fx.pastOpacity : fx.idleOpacity),
      height: 1.35,
      letterSpacing: fx.letterSpacing,
    );
    // Classic keeps its near-white look; other bases take the colourway.
    final activeColor = fx.base == 2
        ? Color.lerp(Colors.white, c1, .35)!
        : (fx.base == 1 ? Color.lerp(Colors.white, c1, .22)! : c1);
    // Pulse Glow (v2.33): the glow radius breathes across the
    // line — swells to mid-line, settles by the end.
    final glowR = fx.glow * (fx.pulse ? (0.78 + 0.5 * sin(progress * pi)) : 1.0);
    final activeStyle = TextStyle(
      fontFamily: widget.fontFamily,
      fontSize: fs + fx.sizeBoost,
      fontWeight: FontWeight.w900,
      color: activeColor,
      height: 1.35,
      letterSpacing: fx.letterSpacing,
      shadows: fx.glow > 0
          ? [Shadow(color: c1, blurRadius: glowR),
             if (fx.base == 11) Shadow(color: c2, blurRadius: glowR * 1.7)]
          : null,
    );

    Widget text;
    if (active && fx.wordKaraoke) {
      final words = rawText.split(' ');
      final lit = (progress * words.length).floor();
      text = Text.rich(
        TextSpan(children: [
          for (var w = 0; w < words.length; w++)
            TextSpan(
              text: w == words.length - 1 ? words[w] : '${words[w]} ',
              style: w < lit
                  ? activeStyle
                  : TextStyle(fontFamily: widget.fontFamily,
                      fontSize: fs + fx.sizeBoost, fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(.5), height: 1.35),
            ),
        ]),
        maxLines: 2, overflow: TextOverflow.ellipsis,
      );
    } else if (active && fx.typewriter) {
      final shown = (progress * rawText.length).ceil().clamp(0, rawText.length);
      text = Text(rawText.substring(0, shown),
          style: activeStyle, maxLines: 2, overflow: TextOverflow.ellipsis,
          textAlign: fx.center ? TextAlign.center : TextAlign.left);
    } else if (active && fx.outline) {
      // Outline (v2.33): hollow letters — a stroked foreground
      // paint instead of a fill, glow shadows still apply.
      text = Text(rawText,
          style: TextStyle(
            fontFamily: widget.fontFamily,
            fontSize: fs + fx.sizeBoost,
            fontWeight: FontWeight.w900,
            height: 1.35,
            letterSpacing: fx.letterSpacing,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = activeColor,
            shadows: activeStyle.shadows,
          ),
          maxLines: 2, overflow: TextOverflow.ellipsis,
          textAlign: fx.center ? TextAlign.center : TextAlign.left);
    } else {
      text = AnimatedDefaultTextStyle(
        style: active ? activeStyle : idleStyle,
        duration: widget.animate ? const Duration(milliseconds: 380) : Duration.zero,
        curve: Curves.easeOut,
        child: Text(rawText,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            textAlign: fx.center ? TextAlign.center : TextAlign.left),
      );
      if (active && fx.gradient) {
        text = ShaderMask(
          shaderCallback: (r) => LinearGradient(colors: [c1, c2]).createShader(r),
          blendMode: BlendMode.srcIn,
          child: text,
        );
      }
    }
    if (active && fx.focusIn && progress < 0.9) {
      // Focus Pull (v2.33): the singing line starts soft and
      // snaps into focus over its first stretch.
      final sig = 2.6 * (1 - progress / 0.9);
      if (sig > 0.15) {
        text = ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sig, sigmaY: sig),
          child: text,
        );
      }
    }
    if (!active && fx.blur > 0) {
      final sigma = fx.blur * widget.blurScale;
      text = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Opacity(opacity: fx.idleOpacity, child: text),
      );
    }
    Widget row = AnimatedScale(
      scale: active ? fx.scale : 1.0,
      duration: widget.animate ? const Duration(milliseconds: 420) : Duration.zero,
      curve: fx.bounce ? Curves.easeOutBack : Curves.easeOutCubic,
      alignment: fx.center ? Alignment.center : Alignment.centerLeft,
      child: text,
    );
    if (fx.slide || fx.rise) {
      row = AnimatedSlide(
        offset: active
            ? Offset.zero
            : (fx.rise ? const Offset(0, .16) : const Offset(.015, 0)),
        duration: widget.animate ? const Duration(milliseconds: 420) : Duration.zero,
        curve: Curves.easeOutCubic,
        child: row,
      );
    }
    if (!active && fx.wave) {
      row = Transform.translate(offset: Offset(sin(i * .85) * 7, 0), child: row);
    }
    if (active && fx.pill) {
      final p = progress.clamp(0.0, 1.0);
      row = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: fx.sweep
            ? BoxDecoration(
                // Sweep Pill (v2.33): the fill edge follows the
                // singing progress across the pill.
                gradient: LinearGradient(colors: [
                  c1.withOpacity(.34), c1.withOpacity(.34),
                  c1.withOpacity(.12), c1.withOpacity(.12),
                ], stops: [0, p, p, 1]),
                borderRadius: BorderRadius.circular(14),
              )
            : BoxDecoration(
                color: c1.withOpacity(.20),
                borderRadius: BorderRadius.circular(14),
              ),
        child: row,
      );
    }
    return InkWell(
      onTap: () => widget.player.seek(line.time),
      child: Align(
        alignment: fx.center ? Alignment.center : Alignment.centerLeft,
        child: row,
      ),
    );
  }
}

/// Full-screen lyrics: accent-tinted backdrop, big synced lines,
/// effect switcher in the app bar, mini transport row.
class LyricsFullScreen extends StatelessWidget {
  final MediaItem item;
  const LyricsFullScreen({super.key, required this.item});
  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final store = context.watch<AppStore>();
    final accent = Theme.of(context).colorScheme.primary;
    final cur = player.current ?? item;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B14),
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0x8A000000),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cur.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(cur.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Lyrics effects',
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            onPressed: () => showLyricsStyleSheet(context),
          ),
          IconButton(
            tooltip: 'Add / edit lyrics',
            icon: const Icon(Icons.edit_note, color: Colors.white),
            onPressed: () => showLyricsSourceSheet(context, cur),
          ),
        ],
      ),
      body: Stack(fit: StackFit.expand, children: [
        // glass backdrop: the cover itself, blurred, with its own tint
        if (cur.artworkUrl != null && cur.artworkUrl!.startsWith('/'))
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
            child: Image.file(File(cur.artworkUrl!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        FutureBuilder<Color?>(
          future: DominantColor.of(cur),
          builder: (_, csnap) => Container(
              color: (csnap.data ?? accent).withOpacity(.26)),
        ),
        Container(color: Colors.black.withOpacity(.22)),
        SafeArea(
          bottom: false,
          child: FutureBuilder<LyricsData>(
            future: _lyricsFor(store, cur),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              final data = snap.data!;
              if (data.hasSynced) {
                return SyncedLyricsView(lines: data.synced!, player: player,
                    style: store.lyricsStyle, accent: accent, fontSize: 21,
                    blurScale: store.lyricsBlurScale, animate: store.animatedLyrics,
                    customColor: store.lyricsColorValue == 0 ? null : Color(store.lyricsColorValue),
                    fontFamily: LyricsFonts.familyOf(store.lyricsFont));
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Text(data.plain ?? 'No lyrics found for this track.',
                    style: TextStyle(fontFamily: LyricsFonts.familyOf(store.lyricsFont),
                        height: 1.6, color: Colors.white, fontSize: 17)),
              );
            },
          ),
        ),
      ]),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0), Colors.black.withOpacity(.28)],
              ),
            ),
            child: SafeArea(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(iconSize: 34, icon: const Icon(Icons.skip_previous_rounded, color: Colors.white), onPressed: player.previous),
                IconButton(iconSize: 52, icon: Icon(player.playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white), onPressed: player.toggle),
                IconButton(iconSize: 34, icon: const Icon(Icons.skip_next_rounded, color: Colors.white), onPressed: player.next),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lyrics for the full-screen view: the user's saved lyrics win,
/// then the offline cache, then LRCLIB (same rule as the Now Playing
/// panel). A fresh online fetch is saved to the cache automatically.
Future<LyricsData> _lyricsFor(AppStore store, MediaItem item) async {
  final custom = store.customLyrics[item.id];
  if (custom != null && custom.trim().isNotEmpty) {
    final lines = Api.parseLrc(custom);
    if (lines.length > 1) {
      return LyricsData(
          plain: lines.map((l) => l.text).join('\n'), synced: lines);
    }
    return LyricsData(plain: custom.trim());
  }
  if (item.lyrics != null) return LyricsData(plain: item.lyrics);
  final sidecar = await Api.sidecarLyrics(item);
  if (sidecar != null) return sidecar;
  final cached = store.cachedLyricsRaw(item.id);
  if (cached != null) return Api.dataFrom(plain: cached.$1, syncedRaw: cached.$2);
  final data = await Api.fetchLyricsFull(item);
  if (data.plain != null || data.hasSynced) {
    store.saveLyricsCache(item.id, plain: data.plain, syncedRaw: data.rawSynced);
  }
  return data;
}

/// Lyrics source chooser: auto (LRCLIB) vs the user's own lyrics —
/// picked from a file (.lrc/.txt) or written in the built-in editor.
/// User lyrics are saved per track and always win over LRCLIB.
void showLyricsSourceSheet(BuildContext context, MediaItem item) {
  final store = context.read<AppStore>();
  final hasCustom = store.customLyrics[item.id]?.trim().isNotEmpty == true;
  showModalBottomSheet(
    context: context, showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text('Lyrics source', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Auto — find online (LRCLIB)'),
          subtitle: const Text('The app searches synced lyrics automatically'),
          trailing: !hasCustom ? const Icon(Icons.check_circle) : null,
        ),
        ListTile(
          leading: const Icon(Icons.folder_open),
          title: const Text('Choose a lyrics file'),
          subtitle: const Text('.lrc (timed) or .txt — saved for this song'),
          onTap: () async {
            Navigator.pop(sheetCtx);
            final path = await TextFilePicker.pickPath();
            if (path == null || !context.mounted) return;
            try {
              final text = await File(path).readAsString();
              if (text.trim().isEmpty) throw 'empty';
              store.setCustomLyrics(item.id, text);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lyrics saved for this song ✓')));
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not read that file as lyrics text.')));
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Write / edit lyrics myself'),
          subtitle: const Text('Type lines with [mm:ss] timings — saved for this song'),
          trailing: hasCustom ? const Icon(Icons.check_circle) : null,
          onTap: () {
            Navigator.pop(sheetCtx);
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => LyricsEditorScreen(item: item)));
          },
        ),
        if (hasCustom)
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('Remove my lyrics', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              store.removeCustomLyrics(item.id);
              Navigator.pop(sheetCtx);
            },
          ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}
