import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../services/player.dart';
import 'artwork_styles.dart';

/// Album-art style gallery (v2.15): a big LIVE preview of the
/// current song in the selected style — discs spin in the preview —
/// with the full list of styles below. Opens scrolled to the
/// SELECTED style (v2.33, his order).
class ArtStylesScreen extends StatefulWidget {
  const ArtStylesScreen({super.key});
  @override
  State<ArtStylesScreen> createState() => _ArtStylesScreenState();
}

class _ArtStylesScreenState extends State<ArtStylesScreen> {
  final _gridScroll = ScrollController();
  final _selKey = GlobalKey();

  @override
  void dispose() {
    _gridScroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_gridScroll.hasClients) return;
      final store = context.read<AppStore>();
      final w = MediaQuery.of(context).size.width;
      final cellW = (w - 32 - 24) / 3;
      final stride = cellW / .74 + 12;
      final target = ((store.playerStyle ~/ 3) * stride -
              _gridScroll.position.viewportDimension * 0.25)
          .clamp(0.0, _gridScroll.position.maxScrollExtent);
      _gridScroll.jumpTo(target);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _selKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              alignment: 0.2);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final player = context.watch<PlayerService>();
    final cs = Theme.of(context).colorScheme;
    final item = player.current ??
        (store.localAudio.isNotEmpty
            ? store.localAudio.first
            : MediaItem.fromJson(const {
                'id': 'none',
                'title': 'Your Song',
                'artist': '',
                'album': '',
                'path': '',
                'durationMs': 0,
                'isVideo': false,
              }));
    final w = MediaQuery.of(context).size.width;
    final previewSize = (w - 140).clamp(180.0, 250.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Album art style')),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                cs.primary.withOpacity(.30),
                cs.surfaceContainerHighest.withOpacity(.55),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: ArtworkView(
              item: item,
              style: store.playerStyle,
              size: previewSize,
              playing: true, // preview always animates (disc/reels spin)
              accent: cs.primary,
              rotateDisc: store.rotateDisc,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${artStyleNames[store.playerStyle]} — ${item.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5, color: cs.onSurface.withOpacity(.6)),
          ),
        ),
        // GRID of designs (v2.23 — his order: grid, not a list).
        Expanded(
          child: GridView.builder(
            controller: _gridScroll,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: .74,
            ),
            itemCount: artStyleNames.length,
            itemBuilder: (_, i) {
              final selected = store.playerStyle == i;
              final cellW = (w - 32 - 24) / 3;
              return InkWell(
                key: selected ? _selKey : null,
                borderRadius: BorderRadius.circular(16),
                onTap: () => store.update(() => store.playerStyle = i),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: cs.surfaceContainerHighest.withOpacity(.4),
                    border: Border.all(
                      color: selected ? cs.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 7),
                  child: Column(children: [
                    Expanded(
                      child: Center(
                        child: ArtworkView(
                          item: item,
                          style: i,
                          size: cellW - 18,
                          playing: selected && player.playing,
                          accent: cs.primary,
                          rotateDisc: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (selected)
                        Icon(Icons.check_circle, size: 13, color: cs.primary),
                      if (selected) const SizedBox(width: 3),
                      Flexible(
                        child: Text(artStyleNames[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: selected ? cs.primary : null)),
                      ),
                    ]),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
