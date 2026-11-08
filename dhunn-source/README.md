# Dhunn — Music Player (Android, Flutter)

**Version:** 2.34.0 (versionCode 42) · **Package:** `com.novaplayer.nova_player` · **Platform:** Android (arm64) · **Language:** English UI

Dhunn is an offline-first, Spotify-style music player for the songs already on your phone. It scans the device library, plays everything in the background with lock-screen/notification controls, shows **synced lyrics with 40 visual effects**, themes itself from each song's cover art, and updates itself from this GitHub repo — no Play Store needed.

This folder contains the **complete source code** of the v2.34.0 release, exactly as shipped, plus this guide.

---

## Features

### Library
- **Device scan** via MediaStore (native Kotlin scanner with cached HD thumbnails), saved between launches — no re-scan on every open. Auto-refresh **merges** new songs instead of wiping the library.
- **Views:** Songs / Albums / Artists / Folders with drill-down, plus Library tabs: **Your Songs, Playlists, Liked, Lyrics, History**.
- **Lyrics tab** — only songs that already have lyrics (`.lrc` sidecar, user-saved, cached, or embedded), with Play-all and its own sorting: **Title A–Z / Z–A, Artist A–Z / Z–A, Newest, Oldest**.
- **Sorting** for songs: Title, Artist, Newest, Longest.
- **Search** your songs, and a **song locator (◎)** button that scrolls the list exactly to the currently playing song and highlights it.
- **Playlists**: your own, plus smart ones — *Daily Mix* (most played + favourites) and *Recently Added*.
- **Open With support**: file managers can open audio files directly in Dhunn.

### Playback
- Background playback with **notification + lock-screen controls** (`just_audio` + `just_audio_background` / `audio_service`).
- **Session restore**: queue, track and exact position are saved continuously; reopening the app (or tapping the widget) resumes right where you left off.
- Queue with shuffle/repeat, sleep timer, playback speed, seek, and a **native equalizer** attached to the player's audio session.
- Resilient loading: a bad file in a queue falls back to playing the tapped track alone instead of failing the whole queue; load errors are shown, not swallowed.

### Lyrics
- **Synced (LRC) lyrics** with a karaoke-style active line. Sources, in order: your own saved lyrics → embedded lyrics → `.lrc` file beside the song → offline cache → **LRCLIB** fetch (cached for next time).
- **40 curated effects** (cleaned up in v2.33 from 240 look-alike presets): Classic, Karaoke Words, Blur Focus, Glow, Pop Zoom, Pill Highlight, Giant Center, Typewriter, Neon Sign, Wave Flow, plus 10 new mechanics — **Outline, Outline Glow, Focus Pull, Rise, Sweep Pill, Pulse Glow, Karaoke Sweep, Focus Stage, Rise Karaoke, Outline Wave** — and colour specials (Neon Emerald, Neon Pink, Golden Glow, Pearl, Ice Focus, Sunset Flow). The effects gallery opens at your selected effect.
- **12 bundled lyrics fonts** (Poppins, Montserrat, Raleway, Rubik, Oswald, Bebas Neue, Anton, Playfair Display, Dancing Script, Pacifico, Lobster, Caveat).
- **Lyrics editor**: write/paste/import lyrics for any song; bulk lyrics fetch for the whole library (Settings → Downloads).

### Look & feel
- **Theme presets + custom accent colour**; optional **cover theme** — the whole app accent follows the playing song's cover (dominant-colour extraction).
- **58 album-art designs** for sharing/displaying the current song (Gallery Frame, Vinyl Deluxe, Magazine Cover, Cinema Pro, Studio Sleeve, Gallery Card, …); the gallery opens at your selected design. HD cover download per song.
- **Navbar corner-radius slider** (0–60 dp), **default start tab** setting, and **4 launcher-icon variants**.
- Fluid, cover-coloured animated background on Now Playing.

### Drive Mode & Connect
- **Drive Mode**: giant artwork and controls, screen stays on — one tap from Now Playing.
- **Connect device sheet**: this-phone playback + volume, live Wi-Fi/Bluetooth state, paired Bluetooth devices, one-tap system panels.

### Home-screen widget
- Cover, title/artist, **prev / play-pause / next**, and the **live lyric line** (current + next), updated as the song plays.
- **v2.34 rework**: controls run through a crash-proof native receiver — a tap can never stop the app; **Play works even when the app is closed** (the app opens, restores your session and plays). The widget **background follows the cover's colour** and the lyric line wears your **lyrics-effect colour**. Cover art is decoded downsampled (≤288 px) for safety.

### Updates & support
- **In-app updates from GitHub**: the app reads `update.json` in this repo, shows the changelog and downloads the new APK itself.
- Support page with local wallets (JazzCash / Easypaisa / NayaPay) and Binance Pay.
- Battery-optimisation + vendor auto-start helpers (OPPO/vivo/Xiaomi) so background music isn't killed.

---

## Build guide

### Requirements
- Flutter SDK (stable, Dart 3.x) — the app builds with the Flutter version in `pubspec.yaml`'s environment.
- JDK 17 (Android Gradle Plugin requirement).
- Android SDK with platform 36 / build-tools 33+.

### Commands
```bash
flutter pub get
flutter analyze        # expect: no errors (a few info-level lints are known)
flutter test           # 16 tests: LRC parser, store, lyrics FX, update.json shape…

# Release APK — ALWAYS pin the target platform:
flutter build apk --release --target-platform android-arm64
```
> ⚠️ A plain `flutter build apk --release` produces a ~27.5 MB **fat APK** with every ABI. The shipped Dhunn line is **arm64-only** (~12.3 MB) — always pass `--target-platform android-arm64`.

### Signing
The project ships **debug-signed** (Gradle auto-creates `android/debug.keystore`; it is intentionally not in this repo). For a store release you must add your own release keystore + `key.properties`, build an **AAB** (`flutter build appbundle`), and target the SDK level Google Play currently requires.

### Releasing an update (how Dhunn updates itself)
1. Bump `version:` in `pubspec.yaml` (name + code).
2. Build the arm64 APK (above).
3. Upload it to this repo as `dhunn/DHUNN-vX.Y.Z.apk`.
4. Update `update.json` in the repo root: the `latest` block (versionName, versionCode, apkUrl, notes) **and** prepend a changelog entry with `version`, `date` and a `changes[]` list — the app's update dialog renders exactly that shape.
5. Update `dhunn.html` (the website's app page) version + Install link.

---

## Project structure

```
lib/
  main.dart               App entry: background-audio init, session restore, widget feed start
  core/
    models.dart           MediaItem & friends
    store.dart            AppStore (provider): library, playlists, settings, lyrics cache
    theme.dart            Theme presets / accents
    lyrics_fonts.dart     Bundled lyrics-font catalogue
    l10n.dart             English strings
  services/
    player.dart           PlayerService: queue, session persistence (v2.9), EQ hookup
    scanner.dart          MediaStore scan bridge
    api.dart              Lyrics (LRCLIB), sidecar .lrc, parsing (LrcLine)
    lyrics_fx.dart        The 40 curated lyrics effects + legacy-index migration
    dominant.dart         Dominant colour + 3-colour cover palette extraction
    cover.dart            HD cover search/download
    widget_sync.dart      Home-screen widget feed + widget transport actions (v2.34)
    update.dart           GitHub update checker (reads update.json)
    eq.dart, beat.dart    Native EQ bridge, beat feed for the fluid background
    sys.dart              Drive Mode / Connect sheet system bridge (nova/sys)
    ads.dart              Optional interstitial ads module (Monetag JS-SDK zone)
    …
  ui/
    home.dart, library.dart, search.dart      Main tabs (Library incl. Lyrics tab + locator)
    now_playing.dart                          Player screen, lyrics view, Drive/Connect entries
    lyrics_effects.dart, artwork_styles.dart  Effects (40) & art designs (58) galleries
    drive_mode.dart, connect_sheet.dart       v2.33 screens
    settings.dart, downloads.dart, support.dart, updates.dart, onboarding.dart
android/app/src/main/kotlin/com/novaplayer/nova_player/
  MainActivity.kt         AudioServiceActivity + all nova/* method channels
  DhunnWidget.kt          AppWidget provider (renders prefs pushed by Dart)
  DhunnControlReceiver.kt Widget transport middleman (v2.34, crash-proof)
  EqChannel.kt, VizChannel.kt, MonetagAdActivity.kt
assets/fonts/             12 bundled lyrics fonts (~1.1 MB)
test/                     Unit tests (LRC parser, store, FX, updates)
```

### Native ↔ Dart channels
| Channel | Purpose |
|---|---|
| `nova/media` | Scan, file info, battery/auto-start helpers, icon switching, cover download |
| `nova/widget` | Widget data push (Dart→native) + widget actions (native→Dart) |
| `nova/sys` | Keep-screen-on, Wi-Fi/Bluetooth state, paired devices, settings panels |
| `nova/eq`, `nova/viz` | Equalizer control, beat/FFT feed |
| `nova/openfile`, `nova/files`, `nova/bg`, `nova/notify`, `nova/ads` | Open-With intents, pickers, progress notifications, ads |

---

## Notes
- **Permissions**: media audio, notifications, foreground-service (media playback), wake lock; Bluetooth (Connect sheet) — all declared in `AndroidManifest.xml`.
- **MainActivity must extend `AudioServiceActivity`** — extending plain `FlutterActivity` breaks background playback init (hard-won lesson, see `HISTORY.md`).
- The original project README (v1.x development history) is preserved as `HISTORY.md` in this folder.
- No API keys, tokens or private signing keys exist in this codebase; the secrets scan before publishing was clean.
