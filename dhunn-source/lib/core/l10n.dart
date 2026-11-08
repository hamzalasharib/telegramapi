import 'package:flutter/material.dart';

/// Hamza Player localization — ENGLISH ONLY since v2.7 (user's call:
/// one language for the public release keeps the app simpler and a bit
/// smaller). The L API stays so call sites don't change; every lookup
/// resolves to the English map.
class L {
  static const supported = <String, String>{'en': 'English'};
  static const rtl = <String>{};
  static bool isRtl(String code) => false;

  static const _en = {
    'home': 'Home', 'music': 'Music', 'videos': 'Videos', 'liveTv': 'Live TV',
    'library': 'Library', 'settings': 'Settings',
    'searchHint': 'Search songs and artists\u2026',
    'goodMorning': 'Good morning', 'goodAfternoon': 'Good afternoon', 'goodEvening': 'Good evening',
    'recentlyPlayed': 'Recently Played', 'continueListening': 'Continue Listening',
    'continueWatching': 'Continue Watching', 'trending': 'Trending Music',
    'onlineRadio': 'Online Radio', 'podcasts': 'Podcasts', 'localMusic': 'Local Music',
    'localVideos': 'Local Videos', 'favorites': 'Favorites', 'playlists': 'Playlists',
    'history': 'History', 'downloads': 'Downloads', 'songs': 'Songs', 'albums': 'Albums',
    'artists': 'Artists', 'folders': 'Folders', 'online': 'Online', 'offline': 'Offline',
    'channels': 'Channels', 'all': 'All', 'scan': 'Scan Library', 'scanning': 'Scanning device\u2026',
    'noResults': 'Nothing found', 'nowPlaying': 'Now Playing', 'queue': 'Queue',
    'lyrics': 'Lyrics', 'sleepTimer': 'Sleep timer', 'equalizer': 'Equalizer', 'search': 'Search',
    'speed': 'Speed', 'language': 'Language', 'theme': 'Theme', 'dark': 'Dark',
    'light': 'Light', 'amoled': 'AMOLED Black', 'accent': 'Accent color',
    'addToPlaylist': 'Add to playlist', 'newPlaylist': 'New playlist',
    'pasteUrl': 'Play URL', 'importM3u': 'Import M3U / URL', 'epg': 'Programme Guide',
    'grantPermission': 'Allow media permission to scan your device',
    'demoContent': 'Demo', 'live': 'LIVE', 'episodes': 'Episodes',
    'clearHistory': 'Clear history', 'about': 'About', 'pinLock': 'Private folder PIN',
    'dataSaver': 'Data saver (Wi-Fi only streaming)', 'crossfade': 'Crossfade (sec)',
  };

  final String code;
  const L(this.code);
  String t(String key) => _en[key] ?? key;
  String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return t('goodMorning');
    if (h < 17) return t('goodAfternoon');
    return t('goodEvening');
  }
}

/// Access via context: `context.l.t('home')` (always English).
extension LContext on BuildContext {
  L get l => const L('en');
}
