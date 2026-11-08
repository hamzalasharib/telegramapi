import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/lyrics_fx.dart';
import 'models.dart';

/// Central app state + local persistence (SharedPreferences JSON store).
/// Offline-first: favorites, playlists, history, play counts, downloads,
/// settings — everything lives on-device, no backend needed.
class AppStore extends ChangeNotifier {
  // settings
  ThemeMode themeMode = ThemeMode.dark;
  bool amoled = true;
  int accentIndex = 0;
  String localeCode = 'en';
  bool wifiOnly = false;
  double crossfadeSec = 0;
  String userName = ''; // asked from the user; shown in the Home greeting
  bool nameAsked = false;
  bool biometricHint = false;
  bool onboarded = false; // first-run intro completed/skipped

  // ---- Hamza Player customization (v2.0) ----
  int themePreset = 0; // index into NovaTheme.presets; -1 = custom accent
  // Custom lyrics text colour (v2.27): ARGB int, 0 = effect's own.
  int lyricsColorValue = 0;
  int customAccent = 0xFF1ED760; // ARGB when themePreset == -1
  int playerStyle = 1; // 0 Disc (vinyl), 1 Card (square art, Spotify), 2 Full art
  int vizStyle = 0; // 0 Bars, 1 Wave, 2 Rings, 3 Off
  int lyricsStyle = 30; // LyricsFx preset index (base*10+colourway); 30 = Blur Focus · Theme
  int bgEffect = 0; // Now Playing background: 0 Blur art, 1 Gradient, 2 Solid
  bool rotateDisc = true;
  int iconVariant = 0; // launcher icon: 0 Emerald, 1 Ocean, 2 Sunset, 3 Violet
  Map<String, String> customLyrics = {}; // trackId -> raw lyrics (LRC or plain), user-provided
  // Offline cache of lyrics fetched from LRCLIB (v2.7): trackId ->
  // {'p': plain text, 's': raw synced LRC}. Filled AUTOMATICALLY the
  // first time a song's lyrics load online, then served from disk so
  // the same song never needs the network again.
  Map<String, Map<String, String>> lyricsCache = {};
  // HD covers downloaded by CoverService (v2.8): trackId -> file path,
  // re-applied over scanner thumbnails on every load/scan. coverTried
  // remembers failed lookups (retry after a week).
  Map<String, String> coverUpgrades = {};
  // When each HD cover was downloaded (v2.24) — shown in the
  // Downloads screen so the user can see WHICH song's image changed.
  Map<String, int> coverUpgradeTimes = {};
  Map<String, int> coverTried = {};
  // Bulk cover job RESUME state (v2.19): a bulk run can be stopped
  // or the app closed, and later RESUMED exactly where it left off.
  // coverBulkDoneIds = songs already processed by the current job;
  // coverBulkTotal/Found describe it. Last* = last FINISHED job.
  Set<String> coverBulkDoneIds = {};
  int coverBulkTotal = 0;
  int coverBulkFound = 0;
  int coverBulkLastDone = 0;
  int coverBulkLastTotal = 0;
  int coverBulkLastFound = 0;
  int coverBulkLastAt = 0;
  // Bulk LYRICS job resume state (v2.21): one-tap download of
  // lyrics for the whole library, saved offline in lyricsCache.
  Set<String> lyricsBulkDoneIds = {};
  int lyricsBulkTotal = 0;
  int lyricsBulkFound = 0;
  int lyricsBulkLastFound = 0;
  int lyricsBulkLastTotal = 0;
  // Auto-refresh (v2.21): watch for new songs while the app is open
  // (launch, resume and a slow timer) and alert when some appear.
  bool autoSongAlerts = true;
  // Ids of songs that have a .lrc lyrics FILE next to the audio
  // file (v2.23) — indexed after each scan, drives the tile badge.
  Set<String> lyricsFileIds = {};
  // Download + lyrics-display settings (v2.22, PixelPlayer-style):
  int coverRes = 2; // album art resolution: 0 Low 512, 1 Medium 800, 2 High 1200
  bool animatedLyrics = true; // spring animations in the synced lyrics view
  double lyricsBlurScale = 1.0; // blur strength multiplier 0..2 for blur lyrics effects
  int prevLyricsStyle = -1; // style to restore when the blur quick-toggle is turned off
  int seekStyle = 0; // Now Playing progress-bar design (v2.30, 24 styles)
  double navBarRadius = 0; // bottom navbar top-corner radius in dp, 0..60 (v2.33, his request)
  int defaultTab = 0; // tab shown at launch: 0 Home, 1 Search, 2 Library (v2.33, his request)
  int lyricsFont = 0; // index into LyricsFonts.names; 0 = app default (v2.33)

  void saveCoverBulk() => save();
  int lyricsRevision = 0; // bumped whenever custom lyrics change
  String? bgImagePath; // user-picked Now Playing background picture
  bool bgImageBlur = true;
  // Home banner "songs stop in background? tap to fix" — once the
  // user dismisses it, it stays away (v2.24).
  bool bgBannerDismissed = false;
  // Monetag interstitials master switch (Settings) — the user of
  // the app can turn ads fully off; developer default is on.
  bool adsEnabled = true;
  List<String> recentSearches = [];
  bool haptics = true;
  bool coverTheme = true; // app accent follows the playing cover (v2.13)
  // Library content filters (v2.20) — the USER chooses these:
  bool skipShortAudio = false; // hide short voice clips / notes
  int skipShortSec = 30; // "short" = under this many seconds
  String? musicFolder; // only songs from this folder (null = everywhere)
  int hiddenByFilters = 0; // songs the filters hid on the last scan

  void markCoverTried(String trackId) {
    coverTried[trackId] = DateTime.now().millisecondsSinceEpoch;
    save();
  }

  void setCoverUpgrade(String trackId, String path) {
    coverUpgrades[trackId] = path;
    coverUpgradeTimes[trackId] = DateTime.now().millisecondsSinceEpoch;
    coverTried.remove(trackId);
    _applyCoverUpgrades();
    save();
    notifyListeners();
  }

  /// Overlay downloaded HD covers onto the in-memory library.
  void _applyCoverUpgrades() {
    if (coverUpgrades.isEmpty) return;
    MediaItem up(MediaItem e) {
      final p = coverUpgrades[e.id];
      return (p != null && e.artworkUrl != p) ? e.copyWith(artworkUrl: p) : e;
    }
    localAudio = localAudio.map(up).toList();
    localVideo = localVideo.map(up).toList();
    for (final e in [...localAudio, ...localVideo]) {
      _byId[e.id] = e;
    }
  }

  /// Replace the scanned library and PERSIST it, so songs/videos are
  /// still there on the next app launch without re-scanning (user
  /// complaint in v1.1: every open needed a fresh scan-button press).
  /// Stored under dedicated keys — the main save() runs often and must
  /// not rewrite the (potentially large) library JSON every time.
  /// Library filters (v2.20), applied to AUDIO on every scan:
  /// the chosen folder only, and/or no short voice clips.
  bool _passesFilters(MediaItem e) {
    final folder = musicFolder;
    if (folder != null && folder.isNotEmpty) {
      final p = e.filePath.isNotEmpty ? e.filePath : e.source;
      if (!p.startsWith(folder)) return false;
    }
    if (skipShortAudio) {
      final d = e.duration;
      // Duration 0 means "unknown" (file-walk fallback) — a song is
      // never hidden just because its length is unread.
      if (d.inMilliseconds > 0 && d < Duration(seconds: skipShortSec)) {
        return false;
      }
    }
    return true;
  }

  /// [authoritative] is for EXPLICIT user scans (Scan
  /// buttons, onboarding, a filter change): the result
  /// replaces the library wholesale, so deleted songs leave
  /// too. Automatic refreshes (app open / resume / the 45 s
  /// pass) pass false — v2.32 SONGS-VANISH FIX: a transient
  /// MediaStore hiccup (indexing after a reboot, provider
  /// restart) used to return a partial or degraded list and
  /// the auto pass silently replaced the whole library with
  /// it, so songs "disappeared" until a manual rescan. In
  /// merge mode incoming songs are added and existing
  /// entries upgraded by file path — nothing is removed.
  Future<void> setLibrary(List<MediaItem> audio, List<MediaItem> video,
      {bool authoritative = false}) async {
    final before = audio.length;
    audio = audio.where(_passesFilters).toList();
    hiddenByFilters = before - audio.length;
    if (!authoritative && localAudio.isNotEmpty && audio.isNotEmpty) {
      String key(MediaItem e) => e.filePath.isNotEmpty ? e.filePath : e.source;
      final byKey = <String, MediaItem>{for (final e in localAudio) key(e): e};
      for (final e in audio) {
        final k = key(e);
        final old = byKey[k];
        // Upgrade in place by path, but never DOWNGRADE a
        // good MediaStore entry (artwork/metadata) with a
        // bare file-walk one.
        if (old == null || old.artworkUrl == null || e.artworkUrl != null) {
          byKey[k] = e;
        }
      }
      audio = byKey.values.toList()
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    localAudio = audio;
    localVideo = video;
    _applyCoverUpgrades();
    register([...audio, ...video]);
    final sp = await SharedPreferences.getInstance();
    await sp.setString('libraryAudio', jsonEncode(audio.map((e) => e.toJson()).toList()));
    await sp.setString('libraryVideo', jsonEncode(video.map((e) => e.toJson()).toList()));
    notifyListeners();
    indexSidecarLyrics();
  }

  /// True when this song already has lyrics OFFLINE (v2.23): a
  /// .lrc file next to it, user-written lyrics, or cached lyrics.
  bool hasOfflineLyrics(MediaItem item) =>
      lyricsFileIds.contains(item.id) ||
      customLyrics.containsKey(item.id) ||
      lyricsCache.containsKey(item.id);

  bool _indexingSidecar = false;

  /// Index .lrc sidecar files (same folder, same name as the
  /// song). Runs after each scan; cheap exists() checks, yielded
  /// every 40 songs so the UI never stutters.
  Future<void> indexSidecarLyrics() async {
    if (_indexingSidecar) return;
    _indexingSidecar = true;
    try {
      final found = <String>{};
      var n = 0;
      for (final item in localAudio) {
        final p = item.filePath.isNotEmpty ? item.filePath : item.source;
        if (p.startsWith('/')) {
          final slash = p.lastIndexOf('/');
          final dot = p.lastIndexOf('.');
          if (slash > 0 && dot > slash) {
            if (await File('${p.substring(0, dot)}.lrc').exists()) {
              found.add(item.id);
            }
          }
        }
        if (++n % 40 == 0) await Future.delayed(Duration.zero);
      }
      if (found.length != lyricsFileIds.length ||
          !found.containsAll(lyricsFileIds)) {
        lyricsFileIds = found;
        await save();
        notifyListeners();
      }
    } catch (_) {
      // indexing is best-effort; the badge just stays as it was
    } finally {
      _indexingSidecar = false;
    }
  }

  Future<void> _persistLibrary() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        'libraryAudio', jsonEncode(localAudio.map((e) => e.toJson()).toList()));
    await sp.setString(
        'libraryVideo', jsonEncode(localVideo.map((e) => e.toJson()).toList()));
  }

  /// Rename a song inside the app (v2.23): the new title is saved
  /// in the library, so it sticks across restarts and shows
  /// everywhere the song appears (favorites, playlists, history
  /// all resolve through the library).
  Future<void> renameSong(MediaItem item, String newTitle) async {
    newTitle = newTitle.trim();
    if (newTitle.isEmpty) return;
    MediaItem swap(MediaItem e) =>
        e.id == item.id ? e.copyWith(title: newTitle) : e;
    localAudio = localAudio.map(swap).toList();
    localVideo = localVideo.map(swap).toList();
    register([...localAudio, ...localVideo]);
    await _persistLibrary();
    notifyListeners();
  }

  /// Remove a song from every list after its file was deleted.
  Future<void> removeSongEverywhere(MediaItem item) async {
    localAudio.removeWhere((e) => e.id == item.id);
    localVideo.removeWhere((e) => e.id == item.id);
    favoriteIds.remove(item.id);
    for (final pl in playlists) {
      pl.itemIds.remove(item.id);
    }
    history.removeWhere((h) => h.id == item.id);
    coverUpgrades.remove(item.id);
    coverUpgradeTimes.remove(item.id);
    customLyrics.remove(item.id);
    lyricsCache.remove(item.id);
    lyricsFileIds.remove(item.id);
    await _persistLibrary();
    await save();
    notifyListeners();
  }

  // library data
  List<MediaItem> localAudio = [];
  List<MediaItem> localVideo = [];
  bool scanning = false;
  String? scanError;

  final Map<String, MediaItem> _byId = {};
  List<String> favoriteIds = [];
  List<Playlist> playlists = [];
  List<MediaItem> history = []; // most-recent first
  Map<String, int> playCounts = {};
  Map<String, int> positions = {}; // resume positions (ms) for video/audio
  List<String> searchHistory = [];

  MediaItem? byId(String id) => _byId[id];
  void register(Iterable<MediaItem> items) {
    for (final i in items) {
      _byId[i.id] = i;
    }
  }

  bool isFav(MediaItem i) => favoriteIds.contains(i.id);
  void toggleFav(MediaItem i) {
    register([i]);
    if (favoriteIds.contains(i.id)) {
      favoriteIds.remove(i.id);
    } else {
      favoriteIds.insert(0, i.id);
    }
    save();
    notifyListeners();
  }

  List<MediaItem> get favorites =>
      favoriteIds.map(byId).whereType<MediaItem>().toList();

  void setCustomLyrics(String trackId, String text) {
    customLyrics[trackId] = text;
    lyricsRevision++;
    save();
    notifyListeners();
  }

  void removeCustomLyrics(String trackId) {
    customLyrics.remove(trackId);
    lyricsRevision++;
    save();
    notifyListeners();
  }

  /// Raw cached lyrics for a track: (plain, syncedRaw) or null.
  (String?, String?)? cachedLyricsRaw(String trackId) {
    final e = lyricsCache[trackId];
    if (e == null) return null;
    final p = e['p']; final r = e['s'];
    if ((p == null || p.isEmpty) && (r == null || r.isEmpty)) return null;
    return (p, r);
  }

  int get cachedLyricsCount => lyricsCache.length;

  /// Save fetched lyrics for offline reuse. Capped at 800 songs
  /// (oldest evicted) — lyrics are tiny, this is a few MB at most.
  void saveLyricsCache(String trackId, {String? plain, String? syncedRaw}) {
    final p = plain?.trim() ?? '';
    final r = syncedRaw?.trim() ?? '';
    if (p.isEmpty && r.isEmpty) return;
    if (lyricsCache[trackId]?['p'] == p && lyricsCache[trackId]?['s'] == r) return;
    lyricsCache.remove(trackId);
    lyricsCache[trackId] = {'p': p, 's': r};
    while (lyricsCache.length > 800) {
      lyricsCache.remove(lyricsCache.keys.first);
    }
    save();
  }

  void addRecentSearch(String q) {
    q = q.trim();
    if (q.isEmpty) return;
    recentSearches.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    recentSearches.insert(0, q);
    if (recentSearches.length > 12) recentSearches = recentSearches.take(12).toList();
    save();
  }

  void clearRecentSearches() {
    recentSearches.clear();
    save();
    notifyListeners();
  }

  void removeRecentSearch(String q) {
    recentSearches.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    save();
    notifyListeners();
  }

  void addHistory(MediaItem i) {
    register([i]);
    history.removeWhere((h) => h.id == i.id);
    history.insert(0, i);
    if (history.length > 100) history = history.take(100).toList();
    playCounts[i.id] = (playCounts[i.id] ?? 0) + 1;
    save();
    notifyListeners();
  }

  List<MediaItem> get mostPlayed {
    final ids = playCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ids.map((e) => byId(e.key)).whereType<MediaItem>().take(20).toList();
  }

  void setPosition(String id, Duration pos) {
    positions[id] = pos.inMilliseconds;
    save();
  }

  Playlist createPlaylist(String name) {
    final p = Playlist(id: 'pl_${DateTime.now().millisecondsSinceEpoch}', name: name);
    playlists.add(p);
    save();
    notifyListeners();
    return p;
  }

  void addToPlaylist(Playlist p, MediaItem i) {
    register([i]);
    if (!p.itemIds.contains(i.id)) p.itemIds.add(i.id);
    save();
    notifyListeners();
  }

  void deletePlaylist(Playlist p) {
    playlists.removeWhere((x) => x.id == p.id);
    save();
    notifyListeners();
  }

  List<MediaItem> playlistItems(Playlist p) =>
      p.itemIds.map(byId).whereType<MediaItem>().toList();

  void addSearch(String q) {
    searchHistory.remove(q);
    searchHistory.insert(0, q);
    if (searchHistory.length > 15) searchHistory = searchHistory.take(15).toList();
    save();
    notifyListeners();
  }

  Future<void> resetAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
    favoriteIds.clear();
    lyricsCache.clear();
    coverUpgrades.clear();
    coverUpgradeTimes.clear();
    coverTried.clear();
    playlists.clear();
    history.clear();
    playCounts.clear();
    recentSearches.clear();
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    playCounts.clear();
    save();
    notifyListeners();
  }

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[sp.getInt('themeMode') ?? 2]; // dark default
    amoled = sp.getBool('amoled') ?? true;
    accentIndex = sp.getInt('accentIndex') ?? 0;
    lyricsColorValue = sp.getInt('lyricsColorValue') ?? 0;
    localeCode = 'en'; // English only since v2.7 — any old stored choice is ignored
    wifiOnly = sp.getBool('wifiOnly') ?? false;
    crossfadeSec = sp.getDouble('crossfadeSec') ?? 0;
    onboarded = sp.getBool('onboarded') ?? false;
    // (playerStyle/lyricsStyle defaults may be set by the v2.1 migration above)
    themePreset = sp.getInt('themePreset') ?? 0;
    customAccent = sp.getInt('customAccent') ?? 0xFF1ED760;
    playerStyle = sp.getInt('playerStyle') ?? playerStyle;
    seekStyle = sp.getInt('seekStyle') ?? 0;
    navBarRadius = sp.getDouble('navBarRadius') ?? 0;
    defaultTab = sp.getInt('defaultTab') ?? 0;
    lyricsFont = sp.getInt('lyricsFont') ?? 0;
    vizStyle = sp.getInt('vizStyle') ?? 0;
    lyricsStyle = sp.getInt('lyricsStyle') ?? lyricsStyle;
    // v2.1 one-time migration: Spotify artwork card + Blur Focus lyrics.
    if (!(sp.getBool('v21defaults') ?? false)) {
      playerStyle = 1;
      lyricsStyle = 3;
    }
    // v2.8 one-time migration: lyrics styles became 120 LyricsFx
    // presets (index = base*10 + colourway). Old styles 0..5 are the
    // first six bases in the same order -> s*10 is the same effect.
    if (!(sp.getBool('fxPresetsV2') ?? false)) {
      if (lyricsStyle >= 0 && lyricsStyle <= 5) lyricsStyle = lyricsStyle * 10;
    }
    // v2.33: the 240 colour-clone presets were replaced by 40
    // curated ones — map the saved index to the same effect.
    if (!(sp.getBool('fxPresetsV3') ?? false)) {
      lyricsStyle = LyricsFx.migrateIndex(lyricsStyle);
    }
    bgEffect = sp.getInt('bgEffect') ?? 0;
    rotateDisc = sp.getBool('rotateDisc') ?? true;
    iconVariant = sp.getInt('iconVariant') ?? 0;
    bgImagePath = sp.getString('bgImagePath');
    try {
      final cl = jsonDecode(sp.getString('customLyrics') ?? '{}') as Map<String, dynamic>;
      customLyrics = cl.map((k, v) => MapEntry(k, v as String));
    } catch (_) {}
    try {
      final cu = jsonDecode(sp.getString('coverUpgrades') ?? '{}') as Map<String, dynamic>;
      coverUpgrades = cu.map((k, v) => MapEntry(k, v as String));
      final cut = jsonDecode(sp.getString('coverUpgradeTimes') ?? '{}')
          as Map<String, dynamic>;
      coverUpgradeTimes = cut.map((k, v) => MapEntry(k, v as int));
      final ct = jsonDecode(sp.getString('coverTried') ?? '{}') as Map<String, dynamic>;
      coverTried = ct.map((k, v) => MapEntry(k, v as int));
      coverBulkDoneIds =
          ((jsonDecode(sp.getString('coverBulkDoneIds') ?? '[]') as List))
              .map((e) => e as String)
              .toSet();
      coverBulkTotal = sp.getInt('coverBulkTotal') ?? 0;
      coverBulkFound = sp.getInt('coverBulkFound') ?? 0;
      coverBulkLastDone = sp.getInt('coverBulkLastDone') ?? 0;
      coverBulkLastTotal = sp.getInt('coverBulkLastTotal') ?? 0;
      coverBulkLastFound = sp.getInt('coverBulkLastFound') ?? 0;
      coverBulkLastAt = sp.getInt('coverBulkLastAt') ?? 0;
      lyricsBulkDoneIds =
          ((jsonDecode(sp.getString('lyricsBulkDoneIds') ?? '[]') as List))
              .map((e) => e as String)
              .toSet();
      lyricsBulkTotal = sp.getInt('lyricsBulkTotal') ?? 0;
      lyricsBulkFound = sp.getInt('lyricsBulkFound') ?? 0;
      lyricsBulkLastFound = sp.getInt('lyricsBulkLastFound') ?? 0;
      lyricsBulkLastTotal = sp.getInt('lyricsBulkLastTotal') ?? 0;
      autoSongAlerts = sp.getBool('autoSongAlerts') ?? true;
      lyricsFileIds = (sp.getStringList('lyricsFileIds') ?? []).toSet();
      coverRes = sp.getInt('coverRes') ?? 2;
      animatedLyrics = sp.getBool('animatedLyrics') ?? true;
      lyricsBlurScale = sp.getDouble('lyricsBlurScale') ?? 1.0;
      prevLyricsStyle = sp.getInt('prevLyricsStyle') ?? -1;
      skipShortAudio = sp.getBool('skipShortAudio') ?? false;
      skipShortSec = sp.getInt('skipShortSec') ?? 30;
      musicFolder = sp.getString('musicFolder');
    } catch (_) {}
    try {
      final lc = jsonDecode(sp.getString('lyricsCache') ?? '{}') as Map<String, dynamic>;
      lyricsCache = lc.map((k, v) => MapEntry(k,
          (v as Map<String, dynamic>).map((kk, vv) => MapEntry(kk, vv as String))));
    } catch (_) {}
    bgImageBlur = sp.getBool('bgImageBlur') ?? true;
    bgBannerDismissed = sp.getBool('bgBannerDismissed') ?? false;
    adsEnabled = sp.getBool('adsEnabled') ?? true;
    recentSearches = sp.getStringList('recentSearches') ?? [];
    haptics = sp.getBool('haptics') ?? true;
    userName = sp.getString('userName') ?? '';
    nameAsked = sp.getBool('nameAsked') ?? false;
    // Restore the persisted library scan (see setLibrary).
    try {
      final la = jsonDecode(sp.getString('libraryAudio') ?? '[]') as List;
      localAudio = la.map((e) => MediaItem.fromJson(e as Map<String, dynamic>)).toList();
      final lv = jsonDecode(sp.getString('libraryVideo') ?? '[]') as List;
      localVideo = lv.map((e) => MediaItem.fromJson(e as Map<String, dynamic>)).toList();
      register([...localAudio, ...localVideo]);
    } catch (_) {
      // corrupted library cache → user can simply re-scan
    }
    _applyCoverUpgrades();
    favoriteIds = sp.getStringList('favoriteIds') ?? [];
    searchHistory = sp.getStringList('searchHistory') ?? [];
    try {
      final items = jsonDecode(sp.getString('items') ?? '[]') as List;
      register(items.map((e) => MediaItem.fromJson(e as Map<String, dynamic>)));
      final hist = jsonDecode(sp.getString('history') ?? '[]') as List;
      history = hist.map((e) => byId(e as String)).whereType<MediaItem>().toList();
      final pls = jsonDecode(sp.getString('playlists') ?? '[]') as List;
      playlists = pls.map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
      final pc = jsonDecode(sp.getString('playCounts') ?? '{}') as Map<String, dynamic>;
      playCounts = pc.map((k, v) => MapEntry(k, v as int));
      final pos = jsonDecode(sp.getString('positions') ?? '{}') as Map<String, dynamic>;
      positions = pos.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      // corrupted cache → start clean rather than crash
    }
    notifyListeners();
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('themeMode', themeMode.index);
    await sp.setBool('amoled', amoled);
    await sp.setInt('accentIndex', accentIndex);
    await sp.setInt('lyricsColorValue', lyricsColorValue);
    await sp.setString('localeCode', localeCode);
    await sp.setBool('wifiOnly', wifiOnly);
    await sp.setDouble('crossfadeSec', crossfadeSec);
    await sp.setBool('onboarded', onboarded);
    await sp.setBool('v21defaults', true);
    await sp.setBool('fxPresetsV2', true);
    await sp.setBool('fxPresetsV3', true);
    await sp.setInt('themePreset', themePreset);
    await sp.setInt('customAccent', customAccent);
    await sp.setInt('playerStyle', playerStyle);
    await sp.setInt('seekStyle', seekStyle);
    await sp.setDouble('navBarRadius', navBarRadius);
    await sp.setInt('defaultTab', defaultTab);
    await sp.setInt('lyricsFont', lyricsFont);
    await sp.setInt('vizStyle', vizStyle);
    await sp.setInt('lyricsStyle', lyricsStyle);
    await sp.setInt('bgEffect', bgEffect);
    await sp.setBool('rotateDisc', rotateDisc);
    await sp.setInt('iconVariant', iconVariant);
    if (bgImagePath != null) {
      await sp.setString('bgImagePath', bgImagePath!);
    } else {
      await sp.remove('bgImagePath');
    }
    await sp.setBool('bgImageBlur', bgImageBlur);
    await sp.setBool('bgBannerDismissed', bgBannerDismissed);
    await sp.setBool('adsEnabled', adsEnabled);
    await sp.setString('customLyrics', jsonEncode(customLyrics));
    await sp.setString('lyricsCache', jsonEncode(lyricsCache));
    await sp.setString('coverUpgrades', jsonEncode(coverUpgrades));
    await sp.setString('coverUpgradeTimes', jsonEncode(coverUpgradeTimes));
    await sp.setString('coverTried', jsonEncode(coverTried));
    await sp.setString('coverBulkDoneIds', jsonEncode(coverBulkDoneIds.toList()));
    await sp.setInt('coverBulkTotal', coverBulkTotal);
    await sp.setInt('coverBulkFound', coverBulkFound);
    await sp.setInt('coverBulkLastDone', coverBulkLastDone);
    await sp.setInt('coverBulkLastTotal', coverBulkLastTotal);
    await sp.setInt('coverBulkLastFound', coverBulkLastFound);
    await sp.setInt('coverBulkLastAt', coverBulkLastAt);
    await sp.setString('lyricsBulkDoneIds', jsonEncode(lyricsBulkDoneIds.toList()));
    await sp.setInt('lyricsBulkTotal', lyricsBulkTotal);
    await sp.setInt('lyricsBulkFound', lyricsBulkFound);
    await sp.setInt('lyricsBulkLastFound', lyricsBulkLastFound);
    await sp.setInt('lyricsBulkLastTotal', lyricsBulkLastTotal);
    await sp.setBool('autoSongAlerts', autoSongAlerts);
    await sp.setStringList('lyricsFileIds', lyricsFileIds.toList());
    await sp.setInt('coverRes', coverRes);
    await sp.setBool('animatedLyrics', animatedLyrics);
    await sp.setDouble('lyricsBlurScale', lyricsBlurScale);
    await sp.setInt('prevLyricsStyle', prevLyricsStyle);
    await sp.setBool('skipShortAudio', skipShortAudio);
    await sp.setInt('skipShortSec', skipShortSec);
    if (musicFolder != null) {
      await sp.setString('musicFolder', musicFolder!);
    } else {
      await sp.remove('musicFolder');
    }
    await sp.setStringList('recentSearches', recentSearches);
    await sp.setBool('haptics', haptics);
    await sp.setBool('coverTheme', coverTheme);
    await sp.setString('userName', userName);
    await sp.setBool('nameAsked', nameAsked);
    await sp.setStringList('favoriteIds', favoriteIds);
    await sp.setStringList('searchHistory', searchHistory);
    await sp.setString('items', jsonEncode(_byId.values.map((e) => e.toJson()).toList()));
    await sp.setString('history', jsonEncode(history.map((e) => e.id).toList()));
    await sp.setString('playlists', jsonEncode(playlists.map((e) => e.toJson()).toList()));
    await sp.setString('playCounts', jsonEncode(playCounts));
    await sp.setString('positions', jsonEncode(positions));
  }

  void update(void Function() fn) {
    fn();
    save();
    notifyListeners();
  }
}
