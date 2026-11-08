import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../services/player.dart';
import 'widgets.dart';

/// Manual lyrics editor: write or paste lyrics, optionally with LRC
/// timings ([mm:ss.xx] at the start of a line). The "⏱ Insert time"
/// button stamps the CURRENT playback position at the cursor — play
/// the song, tap at each line's start, and you get perfectly synced
/// lyrics. Saved per track in the store; beats LRCLIB after saving.
class LyricsEditorScreen extends StatefulWidget {
  final MediaItem item;
  const LyricsEditorScreen({super.key, required this.item});
  @override
  State<LyricsEditorScreen> createState() => _LyricsEditorScreenState();
}

class _LyricsEditorScreenState extends State<LyricsEditorScreen> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final existing = store.customLyrics[widget.item.id] ??
        widget.item.lyrics ??
        '';
    _ctrl = TextEditingController(text: existing);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _stamp(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '[$m:$s.$cs]';
  }

  void _insertTimestamp() {
    final player = context.read<PlayerService>();
    final pos = player.player.position;
    final stamp = '${_stamp(pos)} ';
    final sel = _ctrl.selection;
    final text = _ctrl.text;
    final at = sel.isValid && sel.start >= 0 ? sel.start : text.length;
    final lineStart = text.lastIndexOf('\n', at - 1) + 1;
    _ctrl.text = text.replaceRange(lineStart, lineStart, stamp);
    _ctrl.selection = TextSelection.collapsed(offset: lineStart + stamp.length);
  }

  void _save() {
    final text = _ctrl.text.trim();
    final store = context.read<AppStore>();
    if (text.isEmpty) {
      store.removeCustomLyrics(widget.item.id);
    } else {
      store.setCustomLyrics(widget.item.id, text);
    }
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lyrics saved for this song ✓')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final isThis = player.current?.id == widget.item.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit lyrics'),
        actions: [
          TextButton(onPressed: _save, child: const Text('SAVE')),
        ],
      ),
      body: Column(children: [
        ListTile(
          leading: artwork(widget.item, size: 44),
          title: Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(widget.item.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Each line is one line of the song. For syncing, start the line with its time, '
            'like [00:12.50] First line. The ⏱ button below inserts the current playback '
            'time while the song plays — play the song, tap it for each line, then save.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.45),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: '[00:00.00] First line…\n[00:05.20] Second line…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                alignLabelWithHint: true,
              ),
              style: const TextStyle(fontSize: 14.5, height: 1.5),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(children: [
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: player.player.positionStream,
                  builder: (_, snap) => OutlinedButton.icon(
                    onPressed: isThis ? _insertTimestamp : null,
                    icon: const Icon(Icons.timer_outlined),
                    label: Text(isThis
                        ? 'Insert time ${_stamp(snap.data ?? Duration.zero)}'
                        : 'Play this song to insert times'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
