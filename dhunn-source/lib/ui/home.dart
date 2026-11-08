import 'package:flutter/material.dart';
import '../services/battery.dart';
import '../services/cover.dart';
import 'package:provider/provider.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'widgets.dart';

/// Spotify-style Home — 100% OFFLINE: greeting, quick-pick grid,
/// jump-back-in rail, recently added, top artists and made-for-you
/// mixes, all from the device library.
class HomeScreen extends StatefulWidget {
  final void Function(int) goToTab;
  const HomeScreen({super.key, required this.goToTab});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _bgExempt = true; // assume fine until the native check returns

  @override
  void initState() {
    super.initState();
    // Quietly fetch HD covers for songs that have none (v2.8) —
    // a small capped pass, a few seconds after Home first appears.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      CoverService.fillMissing(context.read<AppStore>());
      // Background-survival check (v2.24): if the phone is allowed
      // to kill Dhunn to save battery, warn once on Home with a
      // one-tap fix (the banner can also be dismissed for good).
      final ex = await BatteryFix.isExempt();
      if (mounted) setState(() => _bgExempt = ex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final l = context.l;
    final cs = Theme.of(context).colorScheme;
    final visible = store.localAudio;
    final quick = <MediaItem>[];
    final seen = <String>{};
    for (final it in [...store.history, ...store.favorites, ...store.mostPlayed]) {
      if (seen.add(it.id)) quick.add(it);
      if (quick.length == 6) break;
    }
    final recent = [...visible]
      ..sort((a, b) => (b.dateAdded ?? DateTime(0)).compareTo(a.dateAdded ?? DateTime(0)));
    final artists = <String, List<MediaItem>>{};
    for (final it in visible) {
      if (it.artist.isNotEmpty) artists.putIfAbsent(it.artist, () => []).add(it);
    }
    final topArtists = artists.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return ListView(children: [
        if (!_bgExempt && !store.bgBannerDismissed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
            child: Material(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  await BatteryFix.requestExempt();
                  final ex = await BatteryFix.isExempt();
                  if (mounted) setState(() => _bgExempt = ex);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(children: [
                    Icon(Icons.battery_saver_outlined,
                        color: cs.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          'Songs can stop in the background — your phone is allowed to kill Dhunn to save battery. Tap to fix.',
                          style: TextStyle(
                              color: cs.onErrorContainer, fontSize: 13)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: cs.onErrorContainer,
                      tooltip: "Don't show again",
                      onPressed: () =>
                          store.update(() => store.bgBannerDismissed = true),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(children: [
            Expanded(child: Text(store.userName.trim().isEmpty ? l.greeting() : '${l.greeting()}, ${store.userName.trim()}',
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900))),
            Chip(
              avatar: const Icon(Icons.library_music, size: 16),
              label: Text('${visible.length} songs'),
              visualDensity: VisualDensity.compact,
            ),
          ]),
        ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 30, 16, 8),
            child: Column(children: [
              const Icon(Icons.library_music_outlined, size: 56),
              const SizedBox(height: 12),
              const Text('Your offline music library is empty.\nScan the device to add your songs.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => widget.goToTab(2),
                icon: const Icon(Icons.search),
                label: const Text('Open Library & scan'),
              ),
            ]),
          ),
        if (quick.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisExtent: 58, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: quick.length,
              itemBuilder: (_, i) {
                final it = quick[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => playAudioList(context, quick, i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      artwork(it, size: 58, radius: 10),
                      const SizedBox(width: 10),
                      Expanded(child: Text(it.title, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                      const SizedBox(width: 6),
                    ]),
                  ),
                );
              },
            ),
          ),
        if (store.history.isNotEmpty) ...[
          Row(children: [
            Expanded(child: sectionHeader(context, 'Jump back in')),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Clear recently played',
              onPressed: () async {
                if (await confirmDialog(context, 'Clear recently played?',
                    'Your listening history on this device will be removed.')) {
                  store.clearHistory();
                }
              },
            ),
            const SizedBox(width: 4),
          ]),
          _rail(store.history.take(12).toList()),
        ],
        if (recent.isNotEmpty) ...[
          sectionHeader(context, 'Recently added'),
          _rail(recent.take(12).toList()),
        ],
        if (topArtists.isNotEmpty) ...[
          sectionHeader(context, 'Your top artists'),
          SizedBox(
            height: 132,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: topArtists.take(10).length,
              itemBuilder: (_, i) {
                final e = topArtists[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(60),
                  onTap: () => playAudioList(context, e.value, 0),
                  child: Container(
                    width: 100,
                    padding: const EdgeInsets.all(4),
                    child: Column(children: [
                      artwork(e.value.first, size: 76, radius: 40),
                      const SizedBox(height: 6),
                      Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      Text('${e.value.length} songs',
                          style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
        if (visible.isNotEmpty) ...[
          sectionHeader(context, 'Made for you'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              _mixCard(context, Icons.auto_awesome, 'Daily Mix',
                  '${store.mostPlayed.length} tracks • most played + favorites', () {
                final mix = {...store.mostPlayed, ...store.favorites}.toList();
                if (mix.isNotEmpty) playAudioList(context, mix, 0);
              }),
              _mixCard(context, Icons.favorite, 'Liked Songs',
                  '${store.favorites.length} songs', () => widget.goToTab(2)),
            ]),
          ),
          const SizedBox(height: 6),
          sectionHeader(context, 'Your songs', onMore: () => widget.goToTab(2)),
          for (final it in visible.take(8))
            TrackTile(item: it, list: visible.take(8).toList()),
        ],
        const SizedBox(height: 18),
      ]);
  }

  Widget _rail(List<MediaItem> items) => SizedBox(
        height: 172,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final it = items[i];
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => playAudioList(context, items, i),
              child: Container(
                width: 128,
                padding: const EdgeInsets.all(4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  artwork(it, size: 120, radius: 14),
                  const SizedBox(height: 6),
                  Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  Text(it.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ),
            );
          },
        ),
      );

  Widget _mixCard(BuildContext c, IconData icon, String title, String sub, VoidCallback onTap) =>
      Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: [
                Theme.of(c).colorScheme.primary.withOpacity(.35),
                Theme.of(c).colorScheme.surfaceContainerHighest.withOpacity(.5),
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: Theme.of(c).colorScheme.primary, size: 26),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 2),
            ]),
          ),
        ),
      );
}
