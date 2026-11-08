# NOVA PLAYER

## v1.4.0 changes (2026-10-31)
- Now Playing redesigned (user screenshot review): immersive blurred-artwork dark backdrop in both themes, disc shows LOCAL artwork files as well as http art (v1 handled http only), the fallback music-note icon stays upright (only the disc layer spins now) with a vinyl spindle + groove ring, layout fills tall screens via spacers + an "Up next" strip, buffered-position indicator under the seek bar, volume slider row, larger controls with accent glow.

## v1.3.0 changes (2026-10-31)
- Video thumbnails ACTUALLY fixed: the bug was in the Videos grid itself — it only rendered http artwork and ignored local file thumbnails (plus loadThumbnail got a MediaMetadataRetriever fallback chain for frames/embedded art, and a silent auto-refresh scan runs after launch when permission is already granted, backfilling thumbs for libraries saved by older versions).
- Videos tab: folder filter chips, grid/list toggle; long-press a video for the item menu (favorite/playlist/private).
- Playlists/favorites: tapping a video item anywhere now opens the video player with the list as queue (TrackTile was forcing everything through the audio engine).
- MX Player-style video player: horizontal swipe seek with live preview (+/− delta), pinch-to-zoom with reset chip, previous/next within the folder/list + auto-play next, "Resume from … / Start over" prompt, speed sheet (0.25x–3x), Fit/Stretch/Crop, clock in the top bar, overflow menu (screenshot/properties/rotate), hwdec=auto-safe attempted for hardware decoding.

## v1.2.0 changes (2026-10-31)
- ROOT-CAUSE FIX for "songs never play": MainActivity now extends AudioServiceActivity. In v1.0/v1.1 it extended plain FlutterActivity, so AudioService.init() inside JustAudioBackground.init() threw in main(); the error was swallowed, but just_audio_background had already swapped JustAudioPlatform.instance and its late `_audioHandler` was never assigned — every playback call then died with LateInitializationError. Init errors are now also surfaced in the UI instead of swallowed.
- Video thumbnails + local album art: the native scanner generates cached JPEG thumbnails via ContentResolver.loadThumbnail (audio art too); Flutter renders them with Image.file (content:// art URIs were unrenderable). Scanning moved to a background thread.
- Library persistence: scans are saved (AppStore.setLibrary) and restored at launch — no re-scan needed on every open.
- First-run onboarding: 5-page skippable intro with a "Scan my library & start" finish; replayable from Settings → Show intro again.

## v1.1.0 changes (2026-10-31)
- Audio playback engine rebuilt (plain pipeline by default, EQ effects load on demand, content-URI local playback, queue fallback + visible errors) after field reports of songs listing but not playing.
- Video engine switched to libmpv (media_kit): MKV/AVI/FLV/WMV/TS and virtually all codecs, REAL audio-track & subtitle-track selection, screenshots. Leaving the player (back) or backgrounding the app now always stops video (v1 bug fixed).
- Audio Converter: any song/video → WAV or M4A (video→audio extraction, lossless AAC remux when possible) — Library tab → Converter.
- WhatsApp + WhatsApp Business Status Saver: one-time SAF folder pick of the .Statuses folder, then view/save statuses to Pictures/Movies — Library tab → Status Saver.
- Status bar / toolbar now share the page background (no more mismatch), floating gradient mini-player with visible playback errors, Material 3 polish, new Home hero card.
- Note: the all-format video engine makes the APK bigger (~24 MB → ~50 MB).

Ultimate all-in-one **Music, Video, IPTV & Entertainment** app — Flutter/Dart,
offline-first, multilingual, built only on **free, legal sources**.

## What actually works (no fake buttons)

| Area | Implementation |
|---|---|
| Local music | Native MediaStore scan (title/artist/album/duration/art/size) via platform channel `nova/media` + file-walk fallback. Songs/Albums/Artists/Folders views, sort by name/date/duration. |
| Audio engine | `just_audio` + `just_audio_background`: play/pause/next/prev, queue, shuffle, repeat off/all/one, seek, speed 0.5–2x, sleep timer, background playback, lock-screen & notification controls, headset/media-button via audio_service. Play counts, history, resume positions. |
| Equalizer | Real Android audio-FX pipeline: 5-band `AndroidEqualizer` (band gains set on the live session), loudness enhancer, 10 presets (Normal…Vocal Boost). Unsupported devices report platform values honestly. |
| Online music | **iTunes Search API** (free, no key — official 30s previews), **Apple charts RSS** for Trending, **Internet Archive** search + metadata resolution for full public-domain/CC tracks (downloadable). |
| Radio | **Radio Browser API** (free) — 40k+ Shoutcast/Icecast stations, top-voted + search. |
| Podcasts | iTunes podcast directory + real RSS parsing (`xml`) — episode lists, playback, download. |
| Lyrics | **LRCLIB** free API (plain + synced-stripped). |
| Local video | MediaStore video scan, grid with duration/size, continue-watching progress. |
| Video player | `video_player` (ExoPlayer): MP4/MKV*/HLS etc. per platform decoder, double-tap ±10s, swipe brightness (left) / volume (right), speed, Fit/Crop/16:9/4:3, rotate, PiP flag, resume, external .vtt/.srt subtitle attach, video info dialog. (*MKV depends on device codecs — stated honestly in-app.) |
| Online video | Paste-your-own URL player + Blender CC sample films + Mux HLS test stream. |
| IPTV | **iptv-org public index** by default (legal public streams), M3U/M3U8 import by URL or pasted text, **Xtream Codes** `get.php` login, categories, channel numbers, logos, search, favorites, recents, XMLTV **EPG** with now/next, parental PIN for adult-named groups, bundled offline demo playlist fallback. No pirated playlists bundled. |
| Downloads | Queue with progress/cancel for downloadable sources only (Archive, podcasts, sample videos, user URLs). Files land in Library → Downloads, playable offline, deletable. |
| Library | Favorites, custom playlists, smart playlists (Daily Mix, Recently Added, Most Played), history (clearable), downloads, **PIN private folder**. |
| Search | Universal: local songs/videos + online music + radio + podcasts + TV channels, with search history. |
| Languages | 15: English, اردو, العربية, हिन्दी, Français, Deutsch, Español, Português, Türkçe, 中文, 日本語, 한국어, Bahasa Indonesia, বাংলা, فارسی — full core strings for EN/UR/AR/HI/FA, nav+core for the rest with English fallback. RTL layout for UR/AR/FA. Dynamic switching in Settings. |
| Themes | Dark / Light / system, **AMOLED black**, 8 dynamic accent colors, glass UI, gradient home, rotating-disc Now Playing with animated visualizer bars, mini-player. |
| AI-style discovery | Smart mixes from your own play counts/favorites (on-device, no paid API, no data leaves the phone). Natural-language search = universal search above. |

## Honest limits
- iTunes tracks are official **previews** (that's Apple's free API); full tracks come from Internet Archive CC/public-domain, radio, podcasts, or your own files/URLs.
- Spotify/YouTube Music are **never scraped** (per spec).
- EQ/reverb-class effects depend on the device's audio-FX HAL; the UI shows the platform-reported band range.
- PIN is local app-level protection (not encryption).
- Video "brightness" gesture dims via overlay (system brightness plugin intentionally omitted to keep APK small); volume gesture drives real player volume.
- Backend (Supabase/Firebase) is intentionally **not** required: all sync-shaped data (favorites, playlists, history) is modelled in `AppStore` with JSON persistence, ready to back with a REST sync layer later.

## Size strategy
Single-ABI release build (`--target-platform android-arm64`), R8 minify + resource shrink, no `media_kit` (its native libs add ~20 MB), system fonts only, one 33 KB icon asset.

## Build
```bash
flutter pub get
flutter test          # parser / l10n / model tests
flutter build apk --release --target-platform android-arm64
```
Android: minSdk 24, targetSdk 34. iOS project is generated (`ios/`) and uses the same Dart code; iOS media-library scan falls back to the file walk (MediaStore is Android-only).

## Architecture
Feature-folder clean-ish layout: `lib/core` (models, store, theme, l10n),
`lib/services` (player, api, iptv, scanner, downloads), `lib/ui` (screens/widgets).
State: Provider + ChangeNotifier. Persistence: SharedPreferences JSON.
Native: Kotlin `MainActivity` MediaStore bridge.

## APIs used (all free, no keys)
- https://itunes.apple.com/search — music & podcast directory
- https://rss.marketingtools.apple.com — charts
- https://archive.org/advancedsearch.php + /metadata — CC audio
- https://de1.api.radio-browser.info — radio index
- https://lrclib.net/api/get — lyrics
- https://iptv-org.github.io/iptv/index.m3u — public TV index

Made by Hamza Shafiq.
