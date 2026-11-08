import 'package:flutter/material.dart';
import '../services/update.dart';

/// Updates & FAQs (v2.16): everything on this screen — latest
/// version, download link, the full changelog and the FAQs — comes
/// from the owner's update.json on GitHub, so it can all be edited
/// there without releasing a new app version.
class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});
  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  UpdateInfo? _info;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final info = await UpdateService.fetch();
    if (!mounted) return;
    setState(() {
      _info = info;
      _loading = false;
      _failed = info == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final info = _info;
    final hasUpdate = info?.updateAvailable ?? false;
    final faqs = (info != null && info.faqs.isNotEmpty)
        ? info.faqs
        : kFallbackFaqs;
    return Scaffold(
      appBar: AppBar(title: const Text('Updates & FAQs')),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        // ---- status card ----
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                cs.primary.withOpacity(.85),
                Color.lerp(cs.primary, Colors.black, .35)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.music_note_rounded, color: Colors.white, size: 30),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Dhunn',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900)),
                Text('Version $kAppVersionName',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ]),
            ]),
            const SizedBox(height: 14),
            if (_loading)
              const Row(children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 10),
                Text('Checking for updates…',
                    style: TextStyle(color: Colors.white, fontSize: 13.5)),
              ])
            else if (_failed)
              const Text(
                  'Could not check right now — please check your internet and try again.',
                  style: TextStyle(color: Colors.white, fontSize: 13.5))
            else if (hasUpdate)
              Text('🎉 New version ${info!.latestName} is available!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800))
            else
              const Text('✅ You are on the latest version.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(children: [
              FilledButton.tonalIcon(
                onPressed: _loading ? null : _check,
                icon: const Icon(Icons.refresh, size: 17),
                label: const Text('Check for updates'),
              ),
              if (hasUpdate) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        UpdateService.openDownload(info!.apkUrl),
                    icon: const Icon(Icons.download, size: 17),
                    label: const Text('Update now'),
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87),
                  ),
                ),
              ],
            ]),
          ]),
        ),
        if (hasUpdate && info!.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(info.notes,
                style: const TextStyle(fontSize: 13.5, height: 1.45)),
          ),
        // ---- changelog ----
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
          child: Text('Changelog',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        if (info != null && info.changelog.isNotEmpty)
          for (final e in info.changelog)
            ExpansionTile(
              title: Text('Version ${e.version}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: e.date.isEmpty ? null : Text(e.date),
              initiallyExpanded:
                  info.changelog.first.version == e.version && hasUpdate,
              children: [
                for (final c in e.changes)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.check_circle_outline, size: 18),
                    title: Text(c, style: const TextStyle(fontSize: 13.5)),
                  ),
              ],
            )
        else if (!_loading)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
                'The changelog could not be loaded. Connect to the internet and check again.',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ),
        // ---- FAQs ----
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
          child: Text('Frequently asked questions',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        for (final f in faqs)
          ExpansionTile(
            title: Text(f.q,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14.5)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(f.a,
                      style: const TextStyle(fontSize: 13.5, height: 1.45)),
                ),
              ),
            ],
          ),
      ]),
    );
  }
}

/// Shown once per launch when GitHub says a newer version exists.
Future<void> maybeShowUpdateDialog(BuildContext context) async {
  final info = await UpdateService.fetch();
  if (info == null || !info.updateAvailable || !context.mounted) return;
  final changes = info.changelog.isNotEmpty &&
          info.changelog.first.version == info.latestName
      ? info.changelog.first.changes
      : const <String>[];
  await showDialog<void>(
    context: context,
    barrierDismissible: !info.forceUpdate,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.system_update, size: 36),
      title: Text('Dhunn ${info.latestName} is here!'),
      content: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (info.notes.isNotEmpty) Text(info.notes),
              for (final c in changes)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(c)),
                      ]),
                ),
            ]),
      ),
      actions: [
        if (!info.forceUpdate)
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later')),
        FilledButton.icon(
          onPressed: () {
            UpdateService.openDownload(info.apkUrl);
            if (!info.forceUpdate) Navigator.pop(ctx);
          },
          icon: const Icon(Icons.download, size: 17),
          label: const Text('Update now'),
        ),
      ],
    ),
  );
}
