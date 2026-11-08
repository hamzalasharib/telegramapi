import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'widgets.dart';

/// Offline search — searches ONLY the device library (title, artist,
/// album). Recent searches + top artists for quick access.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _q = '';

  @override
  void initState() {
    super.initState();
    searchFocusSignal.addListener(_onFocusSignal);
  }

  void _onFocusSignal() {
    if (mounted) _focus.requestFocus();
  }

  @override
  @override
  void dispose() {
    searchFocusSignal.removeListener(_onFocusSignal);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _run(String q) {
    setState(() => _q = q.trim());
    if (q.trim().isNotEmpty) context.read<AppStore>().addRecentSearch(q.trim());
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final l = context.l;
    final all = store.localAudio;
    final q = _q.toLowerCase();
    final results = q.isEmpty
        ? <MediaItem>[]
        : all.where((i) =>
            i.title.toLowerCase().contains(q) ||
            i.artist.toLowerCase().contains(q) ||
            i.album.toLowerCase().contains(q)).toList();
    final artists = <String, int>{};
    for (final it in all) {
      if (it.artist.isNotEmpty) artists[it.artist] = (artists[it.artist] ?? 0) + 1;
    }
    final topArtists = artists.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: _run,
          onSubmitted: (v) { _run(v); _focus.unfocus(); },
          decoration: InputDecoration(
            hintText: l.t('searchHint'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(icon: const Icon(Icons.close), onPressed: () {
                    _ctrl.clear();
                    _run('');
                  }),
            filled: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
          ),
        ),
      ),
      Expanded(child: _q.isEmpty ? _browse(store, topArtists) : _results(results)),
    ]);
  }

  Widget _browse(AppStore store, List<MapEntry<String, int>> topArtists) => ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: const [
            Icon(Icons.offline_pin, size: 16, color: Colors.grey),
            SizedBox(width: 6),
            Text('Offline search — only your device songs',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ),
        if (store.recentSearches.isNotEmpty) ...[
          Row(children: [
            Expanded(child: sectionHeader(context, 'Recent searches')),
            TextButton(
              onPressed: () async {
                if (await confirmDialog(context, 'Clear search history?',
                    'All your recent searches will be removed.')) {
                  store.clearRecentSearches();
                }
              },
              child: const Text('Clear all'),
            ),
            const SizedBox(width: 4),
          ]),
          Wrap(spacing: 8, runSpacing: 4, children: [
            const SizedBox(width: 8),
            ...store.recentSearches.map((r) => InputChip(
                  avatar: const Icon(Icons.history, size: 16),
                  label: Text(r),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => store.removeRecentSearch(r),
                  deleteButtonTooltipMessage: 'Remove',
                  onPressed: () { _ctrl.text = r; _run(r); _focus.unfocus(); },
                )),
          ]),
        ],
        if (topArtists.isNotEmpty) ...[
          sectionHeader(context, 'Your artists'),
          ...topArtists.take(12).map((e) => ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person, size: 20)),
                title: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${e.value} songs'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () { _ctrl.text = e.key; _run(e.key); _focus.unfocus(); },
              )),
        ],
        const SizedBox(height: 16),
      ]);

  Widget _results(List<MediaItem> results) {
    if (results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text('No songs on this device match your search.',
              textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(children: [
      sectionHeader(context, '${results.length} songs found'),
      ...results.map((it) => TrackTile(item: it, list: results)),
      const SizedBox(height: 12),
    ]);
  }
}
