import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart' hide MediaItem;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'core/l10n.dart';
import 'core/models.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'services/dominant.dart';
import 'services/ads.dart';
import 'services/player.dart';
import 'services/widget_sync.dart';
import 'services/notify.dart';
import 'services/open_file.dart';
import 'services/scanner.dart';
import 'ui/home.dart';
import 'ui/library.dart';
import 'ui/now_playing.dart';
import 'ui/onboarding.dart';
import 'ui/search.dart';
import 'ui/settings.dart';
import 'ui/updates.dart';
import 'ui/widgets.dart';

/// LIQUID GLASS test builds (v2.20): compiled with
/// --dart-define=GLASS_TEST=true. The whole shell turns into
/// iPhone-style frosted glass (blurred chrome, floating glass nav
/// bar, aurora backdrop). Normal builds are completely unaffected.
const bool kGlassTest = bool.fromEnvironment('GLASS_TEST');

/// Set when background-audio init fails at startup. Surfaced in the UI —
/// never swallowed silently (lesson from the v1.0/v1.1 `_audioHandler`
/// LateInitializationError that killed all playback).
String? bgAudioInitError;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Background audio + lock-screen / notification controls.
  // Requires MainActivity to extend AudioServiceActivity (it does).
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.novaplayer.nova_player.audio',
      androidNotificationChannelName: 'Dhunn playback',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    bgAudioInitError = 'Background audio init failed: $e';
    debugPrint(bgAudioInitError);
  }
  final store = AppStore();
  await store.load();
  final player = PlayerService();
  // Session restore (v2.9): reload the last queue at the exact saved
  // position (paused) so the mini player is already holding the song
  // the user was listening to when the app was closed.
  await player.restoreSession(store.byId);
  // Home-screen widget feed (v2.31): cover + controls state +
  // live lyric line for the Dhunn player widget.
  WidgetSync.start(store, player);
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider.value(value: player),
    ],
    child: const NovaApp(),
  ));
}

class NovaApp extends StatefulWidget {
  const NovaApp({super.key});

  static (Color, Color?) resolveAccent(AppStore store) {
    if (store.themePreset >= 0 &&
        store.themePreset < NovaTheme.presets.length) {
      final p = NovaTheme.presets[store.themePreset];
      return (p.accent, p.darkBg);
    }
    return (Color(store.customAccent), null);
  }

  @override
  State<NovaApp> createState() => _NovaAppState();
}

class _NovaAppState extends State<NovaApp> {
  PlayerService? _player;
  Color? _coverAccent;
  String? _coverFor;

  @override
  void initState() {
    super.initState();
    _player = context.read<PlayerService>();
    _player!.addListener(_onPlayer);
    _onPlayer();
    AdsService.onSessionStart(context.read<AppStore>());
  }

  /// Cover-matched theme (v2.13): while a song plays, the whole
  /// app's accent follows its album cover's dominant colour.
  void _onPlayer() {
    final item = _player?.current;
    if (item == null) {
      if (_coverAccent != null) setState(() => _coverAccent = null);
      return;
    }
    if (item.id == _coverFor) return;
    _coverFor = item.id;
    AdsService.onTrackStart(context.read<AppStore>());
    DominantColor.of(item).then((c) {
      if (mounted && _coverFor == item.id) {
        setState(() => _coverAccent = c == null ? null : vividAccent(c));
      }
    });
  }

  @override
  void dispose() {
    _player?.removeListener(_onPlayer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final (userAccent, darkBg) = NovaApp.resolveAccent(store);
    final accent =
        (store.coverTheme && _coverAccent != null) ? _coverAccent! : userAccent;
    return MaterialApp(
      title: 'Dhunn',
      debugShowCheckedModeBanner: false,
      theme: _maybeGlass(
          NovaTheme.build(brightness: Brightness.light, accent: accent, amoled: false)),
      darkTheme: _maybeGlass(NovaTheme.build(
          brightness: Brightness.dark, accent: accent, amoled: store.amoled, darkBg: darkBg)),
      themeMode: kGlassTest ? ThemeMode.dark : store.themeMode,
      // English only (v2.7): fixed locale, no localization delegates —
      // framework defaults are English and L returns English strings.
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      builder: (context, child) {
        final platformDark =
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
        final dark = store.themeMode == ThemeMode.dark ||
            (store.themeMode == ThemeMode.system && platformDark);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          ),
          child: child!,
        );
      },
      home: store.onboarded ? const MainShell() : const OnboardingScreen(),
    );
  }
}

/// In glass test builds every surface goes translucent so the
/// blurred backdrop shines through (iOS liquid-glass style).
ThemeData _maybeGlass(ThemeData t) {
  if (!kGlassTest) return t;
  final scheme = t.colorScheme.copyWith(surface: Colors.white.withOpacity(.07));
  return t.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: t.appBarTheme.copyWith(backgroundColor: Colors.transparent),
    navigationBarTheme:
        t.navigationBarTheme.copyWith(backgroundColor: Colors.transparent),
    cardTheme: t.cardTheme.copyWith(color: Colors.white.withOpacity(.07)),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _tab = 0;
  // Auto-refresh (v2.21): raw MediaStore ids seen by the last scan
  // (pre-filter), so a song hidden by a library filter does not
  // re-alert on every pass; only genuinely new songs notify.
  Set<String>? _knownRawIds;
  bool _refreshing = false;
  bool _openingFile = false;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Default tab (v2.33): open on the tab the user picked in
    // Settings → Appearance instead of always Home.
    _tab = context.read<AppStore>().defaultTab.clamp(0, 2);
    _quietRefresh();
    _autoTimer = Timer.periodic(
        const Duration(seconds: 45), (_) => _quietRefresh(delay: false));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) await _checkOpened();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      final store = context.read<AppStore>();
      if (store.userName.trim().isEmpty && !store.nameAsked) {
        store.update(() => store.nameAsked = true);
        if (!mounted) return;
        final name = await askText(
            context, 'Welcome to Dhunn 👋', 'What is your name?');
        if (name != null && name.trim().isNotEmpty) {
          store.update(() => store.userName = name.trim());
        }
      }
      // GitHub update check (v2.16): once per launch, after the
      // name prompt settles. Silent when offline / up to date.
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) await maybeShowUpdateDialog(context);
    });
    if (bgAudioInitError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(bgAudioInitError!),
            duration: const Duration(seconds: 8),
          ));
        }
      });
    }
  }

  /// Silent library refresh: picks up new songs and generates
  /// any missing album art. Only when media permission is ALREADY
  /// granted — never prompts on its own. Auto-refresh (v2.21)
  /// runs this at launch, on resume and every 45 s while the app
  /// is open; when NEW songs appear (and alerts are on) the user
  /// gets a native notification — "New song added" — plus a
  /// snackbar when the app is in front.
  Future<void> _quietRefresh({bool delay = true}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      if (delay) await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final granted = await Permission.audio.isGranted ||
          await Permission.storage.isGranted;
      if (!granted) return;
      final (audio, _) = await MediaScanner.scan();
      if (!mounted) return;
      // v2.32: a degraded pass (MediaStore not ready — the
      // file-walk fallback answered instead) must not touch
      // the library or the baseline; the next pass retries.
      if (!MediaScanner.lastNativeOk) return;
      final store = context.read<AppStore>();
      // The FIRST pass of a session only sets the baseline from
      // the raw scan — it must never alert (v2.27 fix: the old
      // code seeded the baseline from the FILTERED library, so
      // filter-hidden songs looked "new" on every app open and
      // the user got a count toast every single launch).
      final firstPass = _knownRawIds == null;
      final fresh = firstPass
          ? <MediaItem>[]
          : audio.where((e) => !_knownRawIds!.contains(e.id)).toList();
      _knownRawIds = audio.map((e) => e.id).toSet();
      if (audio.isNotEmpty) {
        // Merge mode (not authoritative): new songs are added,
        // nothing is ever removed by an automatic pass, and
        // the video list is preserved instead of wiped.
        await store.setLibrary(audio, store.localVideo);
      }
      if (!mounted) return;
      final visibleNew =
          fresh.where((e) => store.localAudio.any((x) => x.id == e.id)).toList();
      if (visibleNew.isNotEmpty && store.autoSongAlerts) {
        final first = visibleNew.first.title;
        final text = visibleNew.length == 1
            ? 'New song added: $first'
            : '${visibleNew.length} new songs added — latest: $first';
        await ProgressNotify.alert(id: 7003, title: 'New song added', text: text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(text), duration: const Duration(seconds: 4)));
        }
      }
    } catch (_) {
      // background nicety only — manual scan stays in the Library tab
    } finally {
      _refreshing = false;
    }
  }

  /// A song opened from a file manager (v2.21): play it at once
  /// and open the player screen.
  Future<void> _checkOpened() async {
    if (_openingFile) return;
    _openingFile = true;
    try {
      final item = await OpenedFileService.take();
      if (item == null || !mounted) return;
      context.read<AppStore>().register([item]);
      await playAudioList(context, [item], 0);
      if (mounted) {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NowPlayingScreen()));
      }
    } catch (_) {
    } finally {
      _openingFile = false;
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final player = context.read<PlayerService>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      player.saveSession();
    }
    if (state == AppLifecycleState.resumed) {
      _quietRefresh(delay: false);
      _checkOpened();
    }
  }

  void goToTab(int t) {
    // Search re-tap (v2.13): tapping the Search tab while already on
    // it focuses the search field and pops the keyboard open. Return
    // before the unfocus below, which would undo the focus request.
    if (t == 1 && _tab == 1) {
      searchFocusSignal.value++;
      return;
    }
    // Keyboard fix (v2.7): the Search/Library tabs live in an
    // IndexedStack, so their text fields keep focus while hidden —
    // the soft keyboard used to pop back up over Home. Always drop
    // focus when switching tabs.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tab = t);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pages = [
      HomeScreen(goToTab: goToTab),
      const SearchScreen(),
      const LibraryScreen(),
    ];
    if (kGlassTest) return _glassShell(context, pages, l);
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DhunnLogo(size: 28)),
          const SizedBox(width: 8),
          const Text('Dhunn'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l.t('settings'),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const _MiniPlayer(),
        // Navbar corner radius (v2.33): the user-adjustable
        // top-corner radius from Settings → Appearance, applied
        // live via a Consumer so dragging the slider previews.
        Consumer<AppStore>(
          builder: (_, st, __) => ClipRRect(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(st.navBarRadius)),
            child: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: goToTab,
              destinations: [
                NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l.t('home')),
                NavigationDestination(icon: const Icon(Icons.search_outlined), selectedIcon: const Icon(Icons.search), label: l.t('search')),
                NavigationDestination(icon: const Icon(Icons.library_music_outlined), selectedIcon: const Icon(Icons.library_music), label: l.t('library')),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  /// Liquid-glass shell (GLASS_TEST builds only): aurora +
  /// blurred-cover backdrop, frosted AppBar and a FLOATING glass
  /// bottom navigation bar with real BackdropFilter blur.
  Widget _glassShell(BuildContext context, List<Widget> pages, dynamic l) {
    final player = context.watch<PlayerService>();
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.white.withOpacity(.07)),
          ),
        ),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DhunnLogo(size: 28)),
          const SizedBox(width: 8),
          const Text('Dhunn'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(.25)),
            ),
            child: const Text('GLASS TEST',
                style: TextStyle(
                    fontSize: 9.5, letterSpacing: 1.2, color: Colors.white)),
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l.t('settings'),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Stack(fit: StackFit.expand, children: [
        _GlassBackdrop(item: player.current),
        IndexedStack(index: _tab, children: pages),
      ]),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const _MiniPlayer(),
        _GlassNavBar(
          tab: _tab,
          onPick: goToTab,
          labels: [l.t('home'), l.t('search'), l.t('library')],
        ),
      ]),
    );
  }
}

class _MiniPlayer extends StatefulWidget {
  const _MiniPlayer();
  @override
  State<_MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<_MiniPlayer> {
  Color? _dom;
  String? _domFor;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final item = player.current;
    if (item == null) return const SizedBox.shrink();
    if (_domFor != item.id) {
      _domFor = item.id;
      _dom = null;
      DominantColor.of(item).then((c) {
        if (mounted && _domFor == item.id) setState(() => _dom = c);
      });
    }
    // Gradient picked from the cover art itself; text/icon colour is
    // chosen for contrast against it (never flat grey on colour).
    final cs = Theme.of(context).colorScheme;
    final dom = _dom;
    final gradA = dom ?? cs.primary.withOpacity(.28);
    final gradB = dom != null ? Color.lerp(dom, Colors.black, .45)! : cs.surface;
    final probe = dom ?? cs.surface;
    final onCol = probe.computeLuminance() > .42 ? Colors.black : Colors.white;
    final subCol = onCol.withOpacity(.78);
    return StreamBuilder<Duration>(
      stream: player.player.positionStream,
      builder: (_, snap) {
        final dur = player.player.duration ?? item.duration;
        final pos = snap.data ?? player.player.position;
        final pct = dur.inMilliseconds > 0
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0, 1).toDouble()
            : 0.0;
        return Container(
          margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: [gradA, gradB],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 5))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const NowPlayingScreen())),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                LinearProgressIndicator(value: pct, minHeight: 2.5,
                    color: onCol.withOpacity(.9),
                    backgroundColor: Colors.transparent),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(children: [
                    artwork(item, size: 44, radius: 10),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: onCol)),
                      Text(item.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: subCol)),
                    ])),
                    IconButton(icon: const Icon(Icons.skip_previous), color: onCol, onPressed: player.previous),
                    IconButton(
                      icon: Icon(player.playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 36),
                      color: onCol,
                      onPressed: player.toggle,
                    ),
                    IconButton(icon: const Icon(Icons.skip_next), color: onCol, onPressed: player.next),
                  ]),
                ),
                if (player.lastError != null)
                  Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.errorContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(player.lastError!,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11)),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _GlassBackdrop extends StatelessWidget {
  final MediaItem? item;
  const _GlassBackdrop({this.item});

  Widget _blob(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.withOpacity(.38),
          boxShadow: [
            BoxShadow(color: c.withOpacity(.55), blurRadius: 90, spreadRadius: 30)
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final art = item?.artworkUrl;
    return Stack(fit: StackFit.expand, children: [
      const DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF1B1035), Color(0xFF062A33), Color(0xFF05050C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight))),
      Positioned(top: -90, left: -60, child: _blob(const Color(0xFF7C3AED), 260)),
      Positioned(bottom: -110, right: -70, child: _blob(const Color(0xFF00C2FF), 300)),
      Positioned(bottom: 120, left: -80, child: _blob(const Color(0xFF1ED760), 190)),
      if (art != null && art.startsWith('/'))
        Opacity(
          opacity: .30,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 46, sigmaY: 46),
            child: Transform.scale(
              scale: 1.25,
              child: Image.file(File(art),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          ),
        ),
      Container(color: Colors.black.withOpacity(.18)),
    ]);
  }
}

/// Floating liquid-glass bottom navigation (GLASS_TEST builds):
/// real blur of whatever scrolls underneath, frosted tint, light
/// border and a soft pill behind the selected tab — like the
/// latest iPhones.
class _GlassNavBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onPick;
  final List<String> labels;
  const _GlassNavBar({required this.tab, required this.onPick, required this.labels});

  @override
  Widget build(BuildContext context) {
    const icons = [
      (Icons.home_outlined, Icons.home),
      (Icons.search_outlined, Icons.search),
      (Icons.library_music_outlined, Icons.library_music),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.10),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(.22)),
            ),
            child: Row(children: [
              for (var i = 0; i < icons.length; i++)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => onPick(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: tab == i
                            ? Colors.white.withOpacity(.20)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(tab == i ? icons[i].$2 : icons[i].$1,
                            color: Colors.white, size: 23),
                        const SizedBox(height: 2),
                        Text(labels[i],
                            style: TextStyle(
                                color: Colors.white.withOpacity(tab == i ? 1 : .65),
                                fontSize: 11,
                                fontWeight:
                                    tab == i ? FontWeight.w700 : FontWeight.w500)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
