import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'widgets.dart';
import '../services/scanner.dart';

/// First-run intro / tutorial. Skippable. Finishing (or skipping) sets
/// AppStore.onboarded so it never shows again (Settings → "Show intro
/// again" re-enables it). The last page can scan the device library
/// right away so the app opens with songs already listed.
class OnboardingScreen extends StatefulWidget {
  final bool replay;
  const OnboardingScreen({super.key, this.replay = false});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Page {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Page(this.icon, this.color, this.title, this.body);
}

const _pages = <_Page>[
  _Page(Icons.play_circle_fill, Color(0xFF1ED760), 'Welcome to Dhunn',
      'Music only, with a true Spotify-style feel. Every song on your phone, in one beautiful player.'),
  _Page(Icons.library_music, Color(0xFF00C2FF), 'Your music, your way',
      'Playlists, liked songs, albums, artists and folders — everything is scanned into your library. Background play, lock-screen controls and a 5-band equalizer included.'),
  _Page(Icons.lyrics, Color(0xFFFF3D71), 'Live synced lyrics',
      'Lyrics move line by line with the song — only the current line stays sharp, the rest blurs. Auto synced lyrics from LRCLIB with 6 effects, and lyrics you fetch once are saved offline automatically.'),
  _Page(Icons.palette, Color(0xFFE93FD8), 'Make it yours',
      '10 theme presets, custom accent colors, player styles and background effects — customize everything your way.'),
  _Page(Icons.offline_pin, Color(0xFF00D68F), '100% offline, fully private',
      'All your songs play from your own phone — no account, no ads, and no data ever leaves your device. Internet is used only for lyrics and cover art. Let\'s get started!'),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;
  bool _scanning = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _finish() {
    if (widget.replay) {
      Navigator.pop(context);
      return;
    }
    context.read<AppStore>().update(() {
      context.read<AppStore>().onboarded = true;
    });
  }

  Future<void> _scanAndFinish() async {
    setState(() => _scanning = true);
    final store = context.read<AppStore>();
    final ok = await MediaScanner.ensurePermission();
    if (ok) {
      try {
        final (audio, video) = await MediaScanner.scan();
        await store.setLibrary(audio, video, authoritative: true);
      } catch (_) {
        // scan can be retried later from the Music tab
      }
    }
    if (mounted) _finish();
  }

  bool _permAsked = false;

  Future<void> _askCorePermissions() async {
    await MediaScanner.ensurePermission();
    try {
      await Permission.notification.request();
    } catch (_) {}
    if (mounted) setState(() => _permAsked = true);
  }

  /// Every permission the app can ask for, and exactly what it is
  /// used for — no surprises later (his request, v2.14).
  Widget _permissionsPage() {
    final cs = Theme.of(context).colorScheme;
    Widget row(IconData icon, Color color, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: color.withOpacity(.16),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              const SizedBox(height: 2),
              Text(body, style: TextStyle(fontSize: 12.5, height: 1.35,
                  color: cs.onSurface.withOpacity(.72))),
            ])),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 92, height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                colors: [Color(0xFF00C2FF), Color(0xFF0077FF)]),
            boxShadow: [BoxShadow(color: const Color(0xFF00C2FF).withOpacity(.4),
                blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: const Icon(Icons.shield_outlined, size: 46, color: Colors.white),
        ),
        const SizedBox(height: 20),
        const Text('Permissions, clearly explained',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('What the app asks for — and what it is actually for.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(.7))),
        const SizedBox(height: 20),
        row(Icons.library_music, const Color(0xFF1ED760), 'Music & audio files',
            'To find and play the songs saved on your phone. Your files are never uploaded anywhere.'),
        row(Icons.notifications_outlined, const Color(0xFFFFB300), 'Notifications',
            'So you get play / pause / next controls on the lock screen and in the notification shade.'),
        row(Icons.mic_none_outlined, const Color(0xFFFF3D71), 'Microphone (only for Fluid Beat)',
            'Used ONLY to feel the music\'s beat for the animated Fluid Beat background. The app never records, saves or sends any audio. Asked only when you open Fluid Beat.'),
        row(Icons.language, const Color(0xFF00C2FF), 'Internet',
            'Only to fetch song lyrics and high-quality cover images. Your music itself never leaves your phone.'),
        const SizedBox(height: 2),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: _permAsked ? null : _askCorePermissions,
            icon: Icon(_permAsked ? Icons.check_circle : Icons.lock_open_outlined, size: 18),
            label: Text(_permAsked ? 'Music access handled — thank you' : 'Allow music & notifications'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        const SizedBox(height: 8),
        const Text('No account. No ads. No tracking.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length;
    return Scaffold(
      body: Container(
        decoration: NovaTheme.pageGradient(context),
        child: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _pages.length + 1,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  // Permissions page sits just before the final page.
                  if (i == _pages.length - 1) return _permissionsPage();
                  final p = _pages[i < _pages.length - 1 ? i : i - 1];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 132, height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [p.color, p.color.withOpacity(.45)]),
                          boxShadow: [BoxShadow(color: p.color.withOpacity(.45), blurRadius: 30, offset: const Offset(0, 12))],
                        ),
                        child: Icon(p.icon, size: 64, color: Colors.white),
                      ),
                      const SizedBox(height: 34),
                      Text(p.title, textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Text(p.body, textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14.5, height: 1.45,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(.75))),
                      if (i == 0) ...[
                        const SizedBox(height: 22),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: DhunnLogo(size: 64),
                        ),
                      ],
                    ]),
                  );
                },
              ),
            ),
            // dots
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _pages.length + 1; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 24 : 8, height: 8,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(children: [
                if (last)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _scanning ? null : _scanAndFinish,
                      icon: _scanning
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.library_music),
                      label: Text(_scanning ? 'Scanning your library…' : 'Scan my library & start'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                if (last) const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: last
                      ? OutlinedButton(
                          onPressed: _finish,
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Get started without scanning'))
                      : FilledButton(
                          onPressed: () => _ctrl.nextPage(
                              duration: const Duration(milliseconds: 350), curve: Curves.easeOut),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Next')),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
