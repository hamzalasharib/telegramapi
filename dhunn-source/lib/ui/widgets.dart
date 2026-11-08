import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../services/player.dart';
import '../services/share.dart';

/// Bumped by MainShell when the user taps the Search tab while
/// ALREADY on it — SearchScreen listens and focuses its text field
/// (keyboard opens). See _MainShellState.goToTab.
final searchFocusSignal = ValueNotifier<int>(0);

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$sec' : '$m:$sec';
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}

/// Shared UI pieces: artwork, track tiles, section headers, item menu.
/// The Dhunn logo drawn in code (v2.18) so its colour FOLLOWS THE
/// APP THEME: the notes take the current accent (including the
/// cover-matched theme), unlike the static assets/icon.png. Used
/// in the drawer, onboarding and About.
class DhunnLogo extends StatelessWidget {
  final double size;
  const DhunnLogo({super.key, required this.size});
  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final tertiary = Theme.of(context).colorScheme.tertiary;
    return CustomPaint(
      size: Size(size, size),
      painter: _DhunnLogoPainter(accent, tertiary),
    );
  }
}

class _DhunnLogoPainter extends CustomPainter {
  final Color accent;
  final Color tertiary;
  _DhunnLogoPainter(this.accent, this.tertiary);

  Color _shift(double l) {
    final h = HSLColor.fromColor(accent);
    return h.withLightness((h.lightness + l).clamp(0.0, 1.0)).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 100.0;
    final rect = Offset.zero & size;
    // background: dark, tinted by the accent, with a soft glow
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(accent, Colors.black, .76)!,
          const Color(0xFF04070A),
        ],
      ).createShader(rect);
    final rrect = RRect.fromRectAndRadius(
        rect, Radius.circular(size.width * .24));
    canvas.drawRRect(rrect, bgPaint);
    canvas.save();
    canvas.clipRRect(rrect);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [accent.withOpacity(.38), accent.withOpacity(0)],
      ).createShader(Rect.fromCircle(
          center: Offset(30 * u, 22 * u), radius: 62 * u));
    canvas.drawRect(rect, glow);
    // faint vinyl rings
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(.13)
      ..strokeWidth = 1.0 * u;
    canvas.drawCircle(Offset(50 * u, 44 * u), 33.5 * u, ring);
    ring.color = Colors.white.withOpacity(.09);
    canvas.drawCircle(Offset(50 * u, 44 * u), 26.8 * u, ring);
    // the notes, in an accent gradient
    final notePaint = Paint()
      ..shader = LinearGradient(
        colors: [accent, _shift(-.16)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(rect);
    // stems + beam
    canvas.drawRect(Rect.fromLTRB(42.5 * u, 25.5 * u, 47.9 * u, 62.5 * u), notePaint);
    canvas.drawRect(Rect.fromLTRB(71.0 * u, 19.3 * u, 76.4 * u, 56.5 * u), notePaint);
    final beam = Path()
      ..moveTo(42.5 * u, 25.5 * u)
      ..lineTo(76.4 * u, 19.3 * u)
      ..lineTo(76.4 * u, 30.1 * u)
      ..lineTo(42.5 * u, 36.3 * u)
      ..close();
    canvas.drawPath(beam, notePaint);
    // heads: tilted ellipses
    for (final (hx, hy) in [(36.5, 60.0), (65.0, 53.8)]) {
      canvas.save();
      canvas.translate(hx * u, hy * u);
      canvas.rotate(-0.38);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: 23.8 * u, height: 16.7 * u),
          notePaint);
      canvas.restore();
    }
    // EQ bars, accent -> tertiary
    const heights = [0.34, 0.62, 1.0, 0.55, 0.8];
    final bw = 3.0 * u, gap = 2.6 * u;
    var x = 50 * u - (bw * 5 + gap * 4) / 2;
    for (var i = 0; i < 5; i++) {
      final h = 8.5 * u * heights[i];
      final col = Color.lerp(accent, tertiary, i / 4)!.withOpacity(.92);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 77.5 * u - h, bw, h), Radius.circular(bw / 2)),
          Paint()..color = col);
      x += bw + gap;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DhunnLogoPainter old) =>
      old.accent != accent || old.tertiary != tertiary;
}


Widget artwork(MediaItem item, {double size = 52, double radius = 12}) {
  // No-cover fallback (v2.8): THEME colours — a gradient of the active
  // theme accent with the song's initial, instead of a fixed green.
  Widget fallback = Builder(builder: (ctx) {
    final cs = Theme.of(ctx).colorScheme;
    final a = cs.primary;
    final b = Color.lerp(a, cs.tertiary, .45) ?? a;
    final initial = item.title.trim().isEmpty ? '♪' : item.title.trim()[0].toUpperCase();
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
            colors: [a, Color.lerp(a, Colors.black, .35)!, b],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Text(initial,
            style: TextStyle(color: Colors.white.withOpacity(.92),
                fontWeight: FontWeight.w900, fontSize: size * .42)),
        Positioned(
          right: size * .07, bottom: size * .05,
          child: Icon(Icons.music_note_rounded,
              color: Colors.white.withOpacity(.65), size: size * .22),
        ),
      ]),
    );
  });
  final url = item.artworkUrl;
  if (url == null || url.isEmpty) return fallback;
  if (url.startsWith('http')) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(url, width: size, height: size, fit: BoxFit.cover,
          cacheWidth: (size * 2).round(),
          errorBuilder: (_, __, ___) => fallback),
    );
  }
  if (url.startsWith('/')) {
    // Cached MediaStore thumbnail / album-art file from the native scanner.
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(File(url), width: size, height: size, fit: BoxFit.cover,
          cacheWidth: (size * 2).round(),
          errorBuilder: (_, __, ___) => fallback),
    );
  }
  return fallback;
}

Widget sectionHeader(BuildContext c, String title, {VoidCallback? onMore}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 10),
      child: Row(children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const Spacer(),
        if (onMore != null)
          IconButton(onPressed: onMore, icon: const Icon(Icons.arrow_forward_rounded, size: 20)),
      ]),
    );

/// Simple yes/no confirmation used by the clear-history actions.
Future<bool> confirmDialog(BuildContext context, String title, String body,
    {String okLabel = 'Clear'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(okLabel)),
      ],
    ),
  );
  return ok ?? false;
}

Future<void> playAudioList(BuildContext context, List<MediaItem> items, int index) async {
  // Dismiss any open keyboard (e.g. from Search) when a song starts.
  FocusManager.instance.primaryFocus?.unfocus();
  final store = context.read<AppStore>();
  final player = context.read<PlayerService>();
  await player.playQueue(items, index,
      onPlayed: (it) => store.addHistory(it),
      onError: (msg) async {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      });
}

void showItemMenu(BuildContext context, MediaItem item) {
  final store = context.read<AppStore>();
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: artwork(item, size: 44),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(item.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const Divider(),
        ListTile(
          leading: Icon(store.isFav(item) ? Icons.favorite : Icons.favorite_border),
          title: Text(store.isFav(item) ? 'Remove from favorites' : 'Add to favorites'),
          onTap: () {
            store.toggleFav(item);
            Navigator.pop(sheetCtx);
          },
        ),
        ListTile(
          leading: const Icon(Icons.playlist_add),
          title: const Text('Add to playlist'),
          onTap: () {
            Navigator.pop(sheetCtx);
            showPlaylistPicker(context, item);
          },
        ),
        if (item.isLocal) ...[
          const Divider(),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share song'),
            subtitle: const Text('Send the audio file to any app'),
            onTap: () async {
              Navigator.pop(sheetCtx);
              final path = item.filePath.isNotEmpty ? item.filePath : item.source;
              final ok = await ShareService.shareSong(path, item.title);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Could not share this song file.')));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rename'),
            subtitle: const Text('Change the song name in the app'),
            onTap: () async {
              Navigator.pop(sheetCtx);
              final name = await askText(context, 'Rename song', 'Song title',
                  initial: item.title);
              if (name != null && name.trim().isNotEmpty) {
                await store.renameSong(item, name.trim());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Song renamed ✓')));
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Details'),
            onTap: () {
              Navigator.pop(sheetCtx);
              showSongDetails(context, item);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('Delete song', style: TextStyle(color: Colors.redAccent)),
            subtitle: const Text('Remove the file from this phone'),
            onTap: () async {
              Navigator.pop(sheetCtx);
              final ok = await confirmDialog(context, 'Delete song',
                  '"${item.title}" will be deleted from this phone. This cannot be undone.',
                  okLabel: 'Delete');
              if (!ok) return;
              final path = item.filePath.isNotEmpty ? item.filePath : item.source;
              var deleted = false;
              try {
                final f = File(path);
                if (await f.exists()) {
                  await f.delete();
                  deleted = true;
                }
              } catch (_) {
                deleted = false;
              }
              if (!context.mounted) return;
              if (deleted) {
                await store.removeSongEverywhere(item);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Song deleted ✓')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Android blocked deleting this file (it may be on an SD card or owned by another app).')));
              }
            },
          ),
        ],
      ]),
    ),
  );
}

/// Song details dialog (v2.23).
void showSongDetails(BuildContext context, MediaItem item) {
  final path = item.filePath.isNotEmpty ? item.filePath : item.source;
  var size = item.sizeBytes;
  if (size <= 0 && path.startsWith('/')) {
    try {
      size = File(path).lengthSync();
    } catch (_) {}
  }
  final ext = path.contains('.')
      ? path.split('.').last.split('?').first.toUpperCase()
      : '';
  Widget row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 74, child: Text(k,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          Expanded(child: SelectableText(v.isEmpty ? '—' : v,
              style: const TextStyle(fontSize: 13))),
        ]),
      );
  showDialog(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: const Text('Song details'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          row('Title', item.title),
          row('Artist', item.artist),
          row('Album', item.album),
          row('Duration',
              item.duration == Duration.zero ? '' : formatDuration(item.duration)),
          row('Size', formatBytes(size)),
          if (ext.isNotEmpty) row('Format', ext),
          if (item.dateAdded != null)
            row('Added', item.dateAdded!.toString().split('.').first),
          row('Path', path),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Close')),
      ],
    ),
  );
}

/// Animated favorite heart (v2.23 — his request): pops with a
/// springy scale beat every time it is tapped.
class FavHeartButton extends StatefulWidget {
  final MediaItem item;
  final double size;
  final Color inactiveColor;
  const FavHeartButton({super.key, required this.item,
      this.size = 26, this.inactiveColor = Colors.white});
  @override
  State<FavHeartButton> createState() => _FavHeartButtonState();
}

class _FavHeartButtonState extends State<FavHeartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final fav = store.isFav(widget.item);
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) {
        final scale = 1 + 0.42 * sin(pi * _anim.value);
        return Transform.scale(scale: scale, child: child);
      },
      child: IconButton(
        icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
            color: fav ? Colors.redAccent : widget.inactiveColor,
            size: widget.size),
        onPressed: () {
          store.toggleFav(widget.item);
          _anim.forward(from: 0);
        },
      ),
    );
  }
}

void showPlaylistPicker(BuildContext context, MediaItem item) {
  final store = context.read<AppStore>();
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('New playlist'),
          onTap: () async {
            Navigator.pop(sheetCtx);
            final name = await askText(context, 'New playlist', 'Playlist name');
            if (name != null && name.trim().isNotEmpty && context.mounted) {
              final p = store.createPlaylist(name.trim());
              store.addToPlaylist(p, item);
            }
          },
        ),
        ...store.playlists.map((p) => ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(p.name),
              subtitle: Text('${p.itemIds.length} songs'),
              onTap: () {
                store.addToPlaylist(p, item);
                Navigator.pop(sheetCtx);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Added to ${p.name}')));
              },
            )),
      ]),
    ),
  );
}

Future<String?> askText(BuildContext context, String title, String hint,
    {String initial = ''}) async {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dCtx, ctrl.text), child: const Text('OK')),
      ],
    ),
  );
}

class TrackTile extends StatelessWidget {
  final MediaItem item;
  final List<MediaItem> list;
  const TrackTile({super.key, required this.item, required this.list});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final store = context.watch<AppStore>();
    final isCurrent = player.current?.id == item.id;
    return ListTile(
      onLongPress: () => showItemMenu(context, item),
      leading: artwork(item),
      title: Text(item.title,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
              color: isCurrent ? Theme.of(context).colorScheme.primary : null)),
      subtitle: Row(children: [
        Flexible(
          child: Text(
            [item.artist, if (item.duration != Duration.zero) formatDuration(item.duration)]
                .where((s) => s.isNotEmpty).join(' • '),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ),
        if (store.hasOfflineLyrics(item))
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(Icons.lyrics,
                size: 14, color: Theme.of(context).colorScheme.primary),
          ),
      ]),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => showItemMenu(context, item),
      ),
      onTap: () => playAudioList(context, list, list.indexOf(item)),
    );
  }
}

class ShimmerBox extends StatelessWidget {
  final double height;
  const ShimmerBox({super.key, this.height = 72});
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}
