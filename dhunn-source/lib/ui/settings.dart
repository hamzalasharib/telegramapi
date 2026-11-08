import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../core/l10n.dart';
import '../core/lyrics_fonts.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../services/bg.dart';
import '../services/player.dart';
import '../services/scanner.dart';
import 'downloads.dart';
import 'support.dart';
import '../services/cover.dart';
import '../services/lyrics_bulk.dart';
import '../services/battery.dart';
import '../services/app_icon.dart';
import 'drive_mode.dart';
import 'now_playing.dart' show EqSheet, showLyricsStyleSheet;
import '../services/lyrics_fx.dart';
import 'onboarding.dart';
import 'artwork_styles.dart';
import 'art_styles.dart';
import 'seek_bar.dart';
import 'theme_ripple.dart';
import 'updates.dart';
import 'widgets.dart';

/// Settings home (v2.1) — clean CATEGORIES with colored icons; every
/// setting lives inside its category page.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _cat(BuildContext c, {required IconData icon, required Color color,
      required String title, required String sub, required Widget page}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 23,
        backgroundColor: color.withOpacity(.16),
        child: Icon(icon, color: color, size: 23),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final l = context.l;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.t('settings'))),
      body: ListView(children: [
        _cat(context, icon: Icons.palette, color: const Color(0xFF1ED760),
            title: 'Appearance', sub: 'Theme presets, accent colors, dark / AMOLED',
            page: const AppearanceScreen()),
        _cat(context, icon: Icons.play_circle_fill, color: const Color(0xFF00C2FF),
            title: 'Player & Lyrics', sub: 'Player style, background, visualizer, lyrics effects',
            page: const PlayerCustomScreen()),
        _cat(context, icon: Icons.graphic_eq, color: const Color(0xFFFFAA00),
            title: 'Equalizer & Playback', sub: '5-band EQ, bass, loudness, crossfade',
            page: const PlaybackScreen()),
        _cat(context, icon: Icons.library_music, color: const Color(0xFF4F7CFF),
            title: 'My Library', sub: 'Scan device, library stats, clear history',
            page: const LibrarySettingsScreen()),
        _cat(context, icon: Icons.favorite, color: const Color(0xFFE93FD8),
            title: 'Support Dhunn', sub: 'JazzCash, NayaPay, Easypaisa & Binance Pay',
            page: const SupportScreen()),
        _cat(context, icon: Icons.system_update_alt, color: const Color(0xFFFF3D71),
            title: 'Updates & FAQs', sub: 'Check for updates, changelog, help',
            page: const UpdatesScreen()),
        _cat(context, icon: Icons.info, color: const Color(0xFF00B8A9),
            title: 'About', sub: 'Dhunn 2.32.0 • by Hamza Shafiq',
            page: const AboutScreen()),
        const Divider(height: 28),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            radius: 23,
            backgroundColor: cs.error.withOpacity(.14),
            child: Icon(Icons.delete_forever, color: cs.error, size: 23),
          ),
          title: Text('Reset all data', style: TextStyle(color: cs.error, fontWeight: FontWeight.w800, fontSize: 15.5)),
          subtitle: const Text('Clear favorites, playlists, history and settings', style: TextStyle(fontSize: 12)),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Reset everything?'),
                content: const Text('Favorites, playlists, history and settings will be cleared.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
                ],
              ),
            );
            if (ok == true) {
              await store.resetAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('All data cleared')));
              }
            }
          },
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

Widget _head(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)));

// ---------------- Appearance ----------------
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Your name'),
          subtitle: Text(store.userName.trim().isEmpty
              ? 'Shown in the Home greeting'
              : store.userName.trim()),
          trailing: const Icon(Icons.edit_outlined, size: 19),
          onTap: () async {
            final name = await askText(context, 'Your name', 'e.g. Ali');
            if (name != null) store.update(() => store.userName = name.trim());
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.palette),
          title: const Text('Theme matches the playing cover'),
          subtitle: const Text(
              'The whole app takes its colour from the current song\'s album cover. Picking a theme preset or colour below turns this off, so your choice stays.'),
          value: store.coverTheme,
          onChanged: (v) => store.update(() => store.coverTheme = v),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Row(children: [
            const Icon(Icons.apps, size: 21),
            const SizedBox(width: 12),
            const Text('App icon',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(AppIcon.names[store.iconVariant],
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 4; i++)
                GestureDetector(
                  onTap: () async {
                    store.update(() => store.iconVariant = i);
                    final ok = await AppIcon.setVariant(i);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'Icon changed to ${AppIcon.names[i]} — check your home screen'
                            : 'Could not switch the icon on this launcher'),
                        duration: const Duration(seconds: 3),
                      ));
                    }
                  },
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: store.iconVariant == i
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2.4,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.asset(AppIcon.assets[i],
                            width: 62, height: 62),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(AppIcon.names[i],
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: store.iconVariant == i
                                ? FontWeight.w800
                                : FontWeight.w500)),
                  ]),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: Text(
              'Changes the icon on your home screen. It can take a few seconds to update.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.brightness_6),
          title: Text(l.t('theme')),
          trailing: Builder(builder: (segCtx) {
            return SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18)),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 18)),
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android, size: 18)),
              ],
              selected: {store.themeMode},
              onSelectionChanged: (s) => ThemeRipple.show(
                  segCtx, ThemeRipple.centerOf(segCtx),
                  Theme.of(segCtx).colorScheme.primary,
                  onCover: () => store.update(() => store.themeMode = s.first)),
            );
          }),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.contrast),
          title: const Text('AMOLED pure black'),
          value: store.amoled,
          onChanged: (v) => store.update(() => store.amoled = v),
        ),
        _head('Navbar corner radius'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(children: [
            Expanded(
              child: Text(
                  'Match the navbar corners with your device — ${store.navBarRadius.round()} dp',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            TextButton.icon(
              onPressed: store.navBarRadius == 0
                  ? null
                  : () => store.update(() => store.navBarRadius = 0),
              icon: const Icon(Icons.restart_alt, size: 17),
              label: const Text('Reset'),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Slider(
            value: store.navBarRadius,
            min: 0,
            max: 60,
            divisions: 60,
            label: '${store.navBarRadius.round()} dp',
            onChanged: (v) => store.update(() => store.navBarRadius = v),
          ),
        ),
        _head('Default tab'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, children: [
            for (final (i, label) in const [
              (0, 'Home'),
              (1, 'Search'),
              (2, 'Library')
            ])
              ChoiceChip(
                label: Text(label),
                selected: store.defaultTab == i,
                onSelected: (_) => store.update(() => store.defaultTab = i),
              ),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Text('The tab Dhunn opens on when you launch the app.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        _head('Theme presets'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, mainAxisExtent: 84, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: NovaTheme.presets.length,
            itemBuilder: (itemCtx, i) {
              final p = NovaTheme.presets[i];
              final sel = store.themePreset == i;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => ThemeRipple.show(
                    itemCtx, ThemeRipple.centerOf(itemCtx), p.accent,
                    onCover: () => store.update(() {
                          store.themePreset = i;
                          // An explicit preset pick must WIN over the
                          // cover-matched accent (v2.33 fix): with the
                          // cover theme left on, the playing/restored
                          // song's cover colour kept overriding the
                          // preset, so presets looked broken.
                          store.coverTheme = false;
                        })),
                child: Container(
                  decoration: BoxDecoration(
                    color: p.darkBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: sel ? p.accent : Colors.white12, width: sel ? 2.4 : 1),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.play_circle_fill, color: p.accent, size: 26),
                    const SizedBox(height: 6),
                    Text(p.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                        textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (sel) Icon(Icons.check_circle, color: p.accent, size: 14),
                  ]),
                ),
              );
            },
          ),
        ),
        _head('Custom accent color'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            for (final c in NovaTheme.accents)
              Builder(builder: (swCtx) {
                return InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => ThemeRipple.show(
                    swCtx, ThemeRipple.centerOf(swCtx), c,
                    onCover: () => store.update(() {
                          store.themePreset = -1;
                          store.customAccent = c.value;
                          // Same v2.33 fix as presets: an explicit
                          // colour pick disables the cover override.
                          store.coverTheme = false;
                        })),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: c, shape: BoxShape.circle,
                    border: Border.all(
                        color: store.themePreset == -1 && store.customAccent == c.value
                            ? Colors.white : Colors.transparent,
                        width: 2.6),
                  ),
                  child: store.themePreset == -1 && store.customAccent == c.value
                      ? const Icon(Icons.check, color: Colors.black54, size: 20)
                      : null,
                ),
              );
              }),
          ]),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ---------------- Lyrics fonts (v2.33) ----------------
/// Font picker for the lyrics views: every bundled font with a
/// live preview line rendered in that font.
class LyricsFontScreen extends StatelessWidget {
  const LyricsFontScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Lyrics font')),
      body: ListView.builder(
        itemCount: LyricsFonts.names.length,
        itemBuilder: (_, i) {
          final family = LyricsFonts.familyOf(i);
          final sel = store.lyricsFont == i;
          return ListTile(
            title: Text(LyricsFonts.names[i],
                style: TextStyle(
                    fontFamily: family,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            subtitle: Text('The night is young and the lyrics roll on',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: family, fontSize: 14.5)),
            trailing: sel
                ? Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary)
                : null,
            selected: sel,
            onTap: () => store.update(() => store.lyricsFont = i),
          );
        },
      ),
    );
  }
}

// ---------------- Player & Lyrics ----------------
class PlayerCustomScreen extends StatelessWidget {
  const PlayerCustomScreen({super.key});

  Widget _choice(BuildContext c, IconData icon, String title,
      Map<int, String> options, int current, ValueChanged<int> onPick) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Wrap(spacing: 8, runSpacing: 4, children: [
        for (final e in options.entries)
          ChoiceChip(
            label: Text(e.value, style: const TextStyle(fontSize: 12)),
            selected: current == e.key,
            onSelected: (_) => onPick(e.key),
            visualDensity: VisualDensity.compact,
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Player & Lyrics')),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.album),
          title: const Text('Album art style'),
          subtitle: Text(artStyleNames[
              store.playerStyle.clamp(0, artStyleNames.length - 1)]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ArtStylesScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.directions_car),
          title: const Text('Drive mode'),
          subtitle: const Text('Giant controls for the car — the screen stays on while it is open'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DriveModeScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.linear_scale),
          title: const Text('Progress bar style'),
          subtitle: Text(
              '${seekStyleNames[store.seekStyle.clamp(0, seekStyleNames.length - 1)]} — ${seekStyleNames.length} designs, tap to browse'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SeekStylesScreen())),
        ),
        _choice(context, Icons.blur_on, 'Player background',
            const {0: 'Blurred artwork', 1: 'Animated gradient', 2: 'Solid', 3: 'Fluid Beat (liquid)'},
            store.bgEffect, (v) => store.update(() => store.bgEffect = v)),
        ListTile(
          leading: const Icon(Icons.image),
          title: const Text('Player background picture'),
          subtitle: Text(store.bgImagePath == null
              ? 'None — the song artwork is used'
              : 'Custom picture set'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (store.bgImagePath != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove picture',
                onPressed: () => store.update(() => store.bgImagePath = null),
              ),
            TextButton(
              child: const Text('Choose'),
              onPressed: () async {
                final path = await BgPicker.pick();
                if (path != null) store.update(() => store.bgImagePath = path);
              },
            ),
          ]),
        ),
        if (store.bgImagePath != null)
          SwitchListTile(
            secondary: const Icon(Icons.blur_on),
            title: const Text('Blur the background picture'),
            subtitle: const Text('Off = picture stays sharp and clear'),
            value: store.bgImageBlur,
            onChanged: (v) => store.update(() => store.bgImageBlur = v),
          ),
        ListTile(
          leading: const Icon(Icons.lyrics),
          title: const Text('Lyrics effect'),
          subtitle: Text('${LyricsFx.of(store.lyricsStyle).name} — ${LyricsFx.presets.length} curated effects, tap to browse'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLyricsStyleSheet(context),
        ),
        ListTile(
          leading: const Icon(Icons.font_download_outlined),
          title: const Text('Lyrics font'),
          subtitle: Text(
              '${LyricsFonts.names[store.lyricsFont.clamp(0, LyricsFonts.names.length - 1)]} — 12 fonts, tap to browse'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LyricsFontScreen())),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Tip: lyrics effects can also be changed inside the player — tap the ✨ icon on the lyrics panel.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.animation),
          title: const Text('Animated lyrics'),
          subtitle: const Text('Spring animations in the synced lyrics view — turn off on low-end phones if lyrics feel heavy'),
          value: store.animatedLyrics,
          onChanged: (v) => store.update(() => store.animatedLyrics = v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.blur_on),
          title: const Text('Lyric blur effect'),
          subtitle: const Text('Only the line being sung stays clear — the rest stays blurred (Blur Focus effect)'),
          value: store.lyricsStyle ~/ 10 == 3,
          onChanged: (v) => store.update(() {
            if (v) {
              if (store.lyricsStyle ~/ 10 != 3) {
                store.prevLyricsStyle = store.lyricsStyle;
              }
              store.lyricsStyle = 30;
            } else if (store.prevLyricsStyle >= 0 &&
                store.prevLyricsStyle ~/ 10 != 3) {
              store.lyricsStyle = store.prevLyricsStyle;
            }
          }),
        ),
        if (store.lyricsStyle ~/ 10 == 3)
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text('Blur strength: ${store.lyricsBlurScale.toStringAsFixed(1)}x'),
            subtitle: Slider(
              value: store.lyricsBlurScale, min: 0, max: 2, divisions: 20,
              onChanged: (v) => store.update(() => store.lyricsBlurScale = v),
            ),
          ),
        SwitchListTile(
          secondary: const Icon(Icons.rotate_right),
          title: const Text('Spin the vinyl disc'),
          value: store.rotateDisc,
          onChanged: (v) => store.update(() => store.rotateDisc = v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.vibration),
          title: const Text('Haptic feedback'),
          value: store.haptics,
          onChanged: (v) => store.update(() => store.haptics = v),
        ),
        const ListTile(
          leading: Icon(Icons.widgets_outlined),
          title: Text('Home-screen widget'),
          subtitle: Text(
              'Cover, play controls and the live lyric line on your home screen — long-press the home screen, open Widgets and add "Dhunn Player"'),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ---------------- Equalizer & Playback ----------------
class PlaybackScreen extends StatelessWidget {
  const PlaybackScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final player = context.read<PlayerService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Equalizer & Playback')),
      body: ListView(children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.graphic_eq)),
          title: const Text('Equalizer & effects'),
          subtitle: const Text('Native device EQ • presets, bass boost, loudness'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showModalBottomSheet(
              context: context, isScrollControlled: true,
              builder: (_) => const EqSheet()),
        ),
        ListTile(
          leading: const Icon(Icons.animation),
          title: Text('Crossfade: ${store.crossfadeSec.toStringAsFixed(0)}s'),
          subtitle: Slider(
            value: store.crossfadeSec, min: 0, max: 12, divisions: 12,
            onChanged: (v) => store.update(() => store.crossfadeSec = v),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: const Text('Sleep timer'),
          subtitle: Text(player.sleepMinutes == null ? 'Off' : '${player.sleepMinutes} minutes'),
        ),
        const _BatteryFixTiles(),
        SwitchListTile(
          secondary: const Icon(Icons.ads_click_outlined),
          title: const Text('Ads'),
          subtitle: const Text(
              'An occasional full-screen ad between songs supports Dhunn\'s development — never in the middle of a song. Turn off for no ads at all.'),
          value: store.adsEnabled,
          onChanged: (v) => store.update(() => store.adsEnabled = v),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

/// Background-stop fix tiles (v2.19.1): battery-optimisation
/// exemption + vendor auto-start. The exemption status re-checks
/// itself whenever the user comes back to the app.
class _BatteryFixTiles extends StatefulWidget {
  const _BatteryFixTiles();
  @override
  State<_BatteryFixTiles> createState() => _BatteryFixTilesState();
}

class _BatteryFixTilesState extends State<_BatteryFixTiles>
    with WidgetsBindingObserver {
  bool? _exempt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final v = await BatteryFix.isExempt();
    if (mounted) setState(() => _exempt = v);
  }

  @override
  Widget build(BuildContext context) {
    final exempt = _exempt;
    return Column(children: [
      ListTile(
        leading: const Icon(Icons.battery_saver_outlined),
        title: const Text('Keep music playing in the background'),
        subtitle: Text(exempt == true
            ? 'Done — the phone is not allowed to stop Dhunn to save battery'
            : 'If songs stop by themselves after a while, your phone is killing Dhunn to save battery. Tap to allow background play.'),
        trailing: exempt == true
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.chevron_right),
        onTap: exempt == true
            ? null
            : () async {
                await BatteryFix.requestExempt();
                // status refreshes on return via the lifecycle hook
              },
      ),
      ListTile(
        leading: const Icon(Icons.power_settings_new),
        title: const Text('Auto-start permission'),
        subtitle: const Text(
            'OPPO, vivo, Xiaomi and some other phones also need this, or background music gets killed'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final ok = await BatteryFix.openAutoStart();
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Could not open auto-start settings on this phone — look for it under Settings, Apps, Dhunn')));
          }
        },
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
            'Tip: also LOCK Dhunn in your recent apps (open recents, long-press the Dhunn card, tap Lock) so clearing recents never closes it.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ),
    ]);
  }
}

// ---------------- Library ----------------
class LibrarySettingsScreen extends StatefulWidget {
  const LibrarySettingsScreen({super.key});
  @override
  State<LibrarySettingsScreen> createState() => _LibrarySettingsScreenState();
}

class _LibrarySettingsScreenState extends State<LibrarySettingsScreen> {
  bool _scanning = false;
  bool _coverBusy = false;
  int _coverDone = 0, _coverTotal = 0, _coverFound = 0;
  bool _lyricsBusy = false;
  int _lyricsDone = 0, _lyricsTotal = 0, _lyricsFound = 0;

  Future<void> _downloadLyrics() async {
    if (_lyricsBusy || LyricsBulkService.running) {
      LyricsBulkService.cancel();
      if (!_lyricsBusy && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Stopping… progress is saved, tap again later to resume'),
            duration: Duration(seconds: 3)));
      }
      return;
    }
    await Permission.notification.request();
    final st0 = context.read<AppStore>();
    setState(() {
      _lyricsBusy = true;
      _lyricsDone = st0.lyricsBulkDoneIds.length;
      _lyricsTotal = st0.lyricsBulkTotal;
      _lyricsFound = st0.lyricsBulkFound;
    });
    final store = context.read<AppStore>();
    final (found, total) = await LyricsBulkService.downloadAll(store,
        onProgress: (done, tot, f) {
      if (mounted) {
        setState(() {
          _lyricsDone = done;
          _lyricsTotal = tot;
          _lyricsFound = f;
        });
      }
    });
    if (mounted) {
      setState(() => _lyricsBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(total == 0
              ? 'All songs already have lyrics saved offline 🎉'
              : 'Lyrics saved offline: $found of $total songs'),
          duration: const Duration(seconds: 4)));
    }
  }

  Future<void> _downloadCovers() async {
    if (_coverBusy || CoverService.bulkRunning) {
      // Stop: progress is SAVED — the next tap resumes (v2.19).
      CoverService.cancelBulk();
      if (!_coverBusy && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Stopping… progress is saved, tap again later to resume'),
            duration: Duration(seconds: 3)));
      }
      return;
    }
    // Notification permission (Android 13+): the job reports its
    // progress in the notification shade while you use the app.
    await Permission.notification.request();
    final st0 = context.read<AppStore>();
    setState(() {
      _coverBusy = true;
      _coverDone = st0.coverBulkDoneIds.length;
      _coverTotal = st0.coverBulkTotal;
      _coverFound = st0.coverBulkFound;
    });
    final store = context.read<AppStore>();
    final player = context.read<PlayerService>();
    final (found, total) = await CoverService.downloadAll(store, player,
        onProgress: (done, tot, f) {
      if (mounted) {
        setState(() {
          _coverDone = done;
          _coverTotal = tot;
          _coverFound = f;
        });
      }
    });
    if (mounted) {
      setState(() => _coverBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(total == 0
              ? 'All songs already have good covers 🎉'
              : 'HD covers downloaded: $found of $total songs'),
          duration: const Duration(seconds: 4)));
    }
  }

  /// After a library filter changes (folder / short clips),
  /// rescan at once so the change is visible immediately (v2.20).
  Future<void> _rescanForFilters() async {
    final ok = await Permission.audio.isGranted ||
        await Permission.storage.isGranted;
    if (!ok) return; // the next manual scan applies the filters
    try {
      final (audio, _) = await MediaScanner.scan();
      if (mounted) {
        await context
            .read<AppStore>()
            .setLibrary(audio, const [], authoritative: true);
      }
    } catch (_) {}
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      var ok = await MediaScanner.ensurePermission();
      if (!ok) {
        ok = await Permission.audio.request().isGranted ||
            await Permission.storage.request().isGranted;
      }
      if (ok && mounted) {
        final (audio, _) = await MediaScanner.scan();
        await context
            .read<AppStore>()
            .setLibrary(audio, const [], authoritative: true);
        // No "N songs" toast (v2.27): the user asked for the
        // song-count popup to stop — the spinner shows progress
        // and failures still report below.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    }
    if (mounted) setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('My Library')),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.library_music),
          title: const Text('Songs on this device'),
          subtitle: Text('${store.localAudio.length} tracks • ${store.playlists.length} playlists • ${store.favorites.length} liked'),
        ),
        ListTile(
          leading: const Icon(Icons.lyrics),
          title: const Text('Lyrics saved offline'),
          subtitle: Text('${store.localAudio.where(store.hasOfflineLyrics).length} songs — fetched lyrics are saved automatically and work without internet'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DownloadsScreen(lyricsFirst: true))),
        ),
        ListTile(
          leading: const Icon(Icons.image),
          title: const Text('HD covers downloaded'),
          subtitle: Text('${store.coverUpgrades.length} songs — missing or small covers are fetched in high quality automatically'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DownloadsScreen())),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: const Text('Songs folder'),
          subtitle: Text(store.musicFolder == null
              ? 'All folders — songs come from everywhere on the phone'
              : 'Only songs from: ${store.musicFolder}'),
          trailing: store.musicFolder == null
              ? const Icon(Icons.chevron_right)
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Use all folders',
                  onPressed: () async {
                    store.update(() => store.musicFolder = null);
                    await _rescanForFilters();
                  }),
          onTap: () async {
            final path = await FolderPicker.pick();
            if (path != null) {
              store.update(() => store.musicFolder = path);
              await _rescanForFilters();
            }
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.voice_over_off),
          title: const Text('Skip short voice clips'),
          subtitle: Text(
              'Hide voice notes and clips under ${store.skipShortSec} seconds — only songs stay in the library'),
          value: store.skipShortAudio,
          onChanged: (v) async {
            store.update(() => store.skipShortAudio = v);
            await _rescanForFilters();
          },
        ),
        if (store.skipShortAudio)
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Treat as "short" under'),
            subtitle: Wrap(spacing: 8, children: [
              for (final sec in [15, 30, 45, 60])
                ChoiceChip(
                  label: Text('${sec}s'),
                  selected: store.skipShortSec == sec,
                  onSelected: (_) async {
                    store.update(() => store.skipShortSec = sec);
                    await _rescanForFilters();
                  },
                ),
            ]),
          ),
        if (store.hiddenByFilters > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Text(
                '${store.hiddenByFilters} items are hidden by your folder / voice-clip filters',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ListTile(
          leading: const Icon(Icons.photo_size_select_large),
          title: const Text('Album art resolution'),
          subtitle: Wrap(spacing: 8, children: [
            for (final (i, label) in const [(0, 'Low · 512px'), (1, 'Medium · 800px'), (2, 'High · 1200px')])
              ChoiceChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                selected: store.coverRes == i,
                onSelected: (_) => store.update(() => store.coverRes = i),
              ),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text('Lower resolution downloads covers much faster and uses less data; High is the sharpest.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('New song alerts & auto-refresh'),
          subtitle: const Text(
              'Dhunn refreshes the library automatically (on open, on return and while it is open) and notifies you when a new song is added'),
          value: store.autoSongAlerts,
          onChanged: (v) => store.update(() => store.autoSongAlerts = v),
        ),
        ListTile(
          leading: const Icon(Icons.lyrics_outlined),
          title: const Text('Download lyrics for all songs (offline)'),
          subtitle: Text(_lyricsBusy
              ? 'Working… $_lyricsDone/$_lyricsTotal songs ($_lyricsFound saved) — tap to stop. Progress shows in notifications and is saved.'
              : store.lyricsBulkTotal > 0
                  ? 'Resume — ${store.lyricsBulkDoneIds.length} of ${store.lyricsBulkTotal} songs done (${store.lyricsBulkFound} saved)'
                  : 'One tap: fetch lyrics for every song and save them on the phone, so lyrics work with no internet'),
          trailing: _lyricsBusy
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download),
          onTap: _downloadLyrics,
        ),
        if (_lyricsBusy && _lyricsTotal > 0)
          LinearProgressIndicator(value: _lyricsDone / _lyricsTotal),
        if (!_lyricsBusy && store.lyricsBulkTotal > 0)
          LinearProgressIndicator(
              value: store.lyricsBulkDoneIds.length / store.lyricsBulkTotal),
        ListTile(
          leading: const Icon(Icons.high_quality),
          title: const Text('Download HD covers for all songs'),
          subtitle: Text(_coverBusy
              ? 'Working… $_coverDone/$_coverTotal songs ($_coverFound downloaded) — tap to stop. You can leave this screen: progress shows in notifications and is saved.'
              : store.coverBulkTotal > 0
                  ? 'Resume — ${store.coverBulkDoneIds.length} of ${store.coverBulkTotal} songs done (${store.coverBulkFound} downloaded)'
                  : 'One tap: high-quality (1200px) covers for every song with a missing or small cover'),
          trailing: _coverBusy
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download),
          onTap: _downloadCovers,
        ),
        if (_coverBusy && _coverTotal > 0)
          LinearProgressIndicator(value: _coverDone / _coverTotal),
        if (!_coverBusy && store.coverBulkTotal > 0)
          LinearProgressIndicator(
              value: store.coverBulkDoneIds.length / store.coverBulkTotal),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Play history'),
          subtitle: Text('${store.history.length} entries'),
          trailing: TextButton(
            onPressed: store.history.isEmpty ? null : store.clearHistory,
            child: const Text('Clear'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: const Text('Scan device for songs'),
          ),
        ),
      ]),
    );
  }
}

// ---------------- About ----------------
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _copy(BuildContext c, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(c)
        .showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(children: [
        const SizedBox(height: 22),
        Center(child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DhunnLogo(size: 96),
        )),
        const SizedBox(height: 14),
        const Center(child: Text('Dhunn',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
        const Center(child: Text('Version 2.33.0',
            style: TextStyle(color: Colors.grey, fontSize: 13))),
        const SizedBox(height: 6),
        const Center(child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text('Your music, your style — a fully offline music player with live synced lyrics, deep themes and a real equalizer.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.45)),
        )),
        const SizedBox(height: 14),
        _head('Developer'),
        ListTile(
          leading: CircleAvatar(backgroundColor: cs.primary.withOpacity(.16),
              child: Icon(Icons.person, color: cs.primary)),
          title: const Text('Hamza Shafiq'),
          subtitle: const Text('Creator & developer'),
        ),
        ListTile(
          leading: CircleAvatar(backgroundColor: cs.primary.withOpacity(.16),
              child: Icon(Icons.send, color: cs.primary)),
          title: const Text('Telegram'),
          subtitle: const Text('t.me/hamzaeditz2'),
          trailing: const Icon(Icons.copy, size: 18),
          onTap: () => _copy(context, 'Telegram', 'https://t.me/hamzaeditz2'),
        ),
        ListTile(
          leading: CircleAvatar(backgroundColor: cs.primary.withOpacity(.16),
              child: Icon(Icons.play_circle_fill, color: cs.primary)),
          title: const Text('YouTube'),
          subtitle: const Text('@hamzashafiq786'),
          trailing: const Icon(Icons.copy, size: 18),
          onTap: () => _copy(context, 'YouTube', 'https://www.youtube.com/@hamzashafiq786'),
        ),
        _head('Highlights'),
        const ListTile(leading: Icon(Icons.offline_pin), title: Text('100% offline playback'),
            subtitle: Text('Every song plays from your own device')),
        const ListTile(leading: Icon(Icons.lyrics), title: Text('Synced lyrics with 6 effects'),
            subtitle: Text('Lyrics by LRCLIB (free)')),
        const ListTile(leading: Icon(Icons.graphic_eq), title: Text('Native equalizer'),
            subtitle: Text('Device audio-FX: bands, bass boost, loudness')),
        const ListTile(leading: Icon(Icons.palette), title: Text('10 themes + custom colors'),
            subtitle: Text('Make the player truly yours')),
        _head('App'),
        ListTile(
          leading: const Icon(Icons.school_outlined),
          title: const Text('Show intro again'),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const OnboardingScreen(replay: true))),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Made with ❤ in Pakistan • Dhunn © 2026 Hamza Shafiq',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      ]),
    );
  }
}
