import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// GitHub-controlled updates (v2.16, his request): the app reads
/// ONE json file from his GitHub repo — latest version + apk link,
/// the full changelog and the FAQs — so he controls everything by
/// editing that file; no app release needed to change the text.
///
/// File: https://github.com/hamzalasharib/telegramapi/blob/main/update.json
/// Raw:  https://raw.githubusercontent.com/hamzalasharib/telegramapi/main/update.json
///
/// RELEASE CHECKLIST: bump kAppVersionCode / kAppVersionName here
/// together with pubspec.yaml on every release.
const kAppVersionCode = 40;
const kAppVersionName = '2.32.0';

const kUpdateJsonUrl =
    'https://raw.githubusercontent.com/hamzalasharib/telegramapi/main/update.json';

class ChangelogEntry {
  final String version;
  final String date;
  final List<String> changes;
  const ChangelogEntry(this.version, this.date, this.changes);
  factory ChangelogEntry.fromJson(Map<String, dynamic> j) {
    var changes = ((j['changes'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    // Fallback (v2.28.1 hardening): entries written in the
    // {versionName, notes} shape still display — the notes text
    // becomes the single change line. A schema slip in
    // update.json must never blank a version again.
    if (changes.isEmpty && (j['notes'] ?? '').toString().isNotEmpty) {
      changes = [(j['notes']).toString()];
    }
    return ChangelogEntry(
      (j['version'] ?? j['versionName'] ?? '').toString(),
      (j['date'] ?? '').toString(),
      changes,
    );
  }
}

class FaqEntry {
  final String q;
  final String a;
  const FaqEntry(this.q, this.a);
  factory FaqEntry.fromJson(Map<String, dynamic> j) =>
      FaqEntry((j['q'] ?? '').toString(), (j['a'] ?? '').toString());
}

class UpdateInfo {
  final String latestName;
  final int latestCode;
  final String apkUrl;
  final String notes;
  final bool forceUpdate;
  final List<ChangelogEntry> changelog;
  final List<FaqEntry> faqs;
  // Support-the-developer payment link (DPay), controlled from
  // update.json so it can go live without an app update (v2.27).
  final String dpayUrl;
  const UpdateInfo({
    required this.latestName,
    required this.latestCode,
    required this.apkUrl,
    required this.notes,
    required this.forceUpdate,
    required this.changelog,
    required this.faqs,
    this.dpayUrl = '',
  });

  bool get updateAvailable => latestCode > kAppVersionCode;

  factory UpdateInfo.fromJson(Map<String, dynamic> j) {
    final latest = (j['latest'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final changelog = ((j['changelog'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ChangelogEntry.fromJson(e.cast<String, dynamic>()))
        .toList();
    var code = (latest['versionCode'] as num?)?.toInt() ?? 0;
    var name = (latest['versionName'] ?? '').toString();
    // Fallback: derive latest from the first changelog entry's
    // version name when the latest block is missing.
    if (name.isEmpty && changelog.isNotEmpty) name = changelog.first.version;
    return UpdateInfo(
      latestName: name,
      latestCode: code,
      apkUrl: (latest['apkUrl'] ?? '').toString(),
      notes: (latest['notes'] ?? '').toString(),
      forceUpdate: latest['forceUpdate'] == true,
      changelog: changelog,
      faqs: ((j['faqs'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => FaqEntry.fromJson(e.cast<String, dynamic>()))
          .toList(),
      dpayUrl: ((j['support'] as Map?)?['dpayUrl'] ?? '').toString(),
    );
  }
}

/// Bundled FAQs so the Updates screen is useful even offline or
/// before the GitHub file is filled in. The GitHub list replaces
/// these when it loads.
const kFallbackFaqs = <FaqEntry>[
  FaqEntry('Is Dhunn free?',
      'Yes — Dhunn is completely free, with no subscriptions and no locked features. It shows an occasional ad to support development, and you can turn ads off completely in Settings → Equalizer & Playback → Ads.'),
  FaqEntry('Does Dhunn need an internet connection?',
      'No. Your songs play fully offline from your phone. Internet is only used for lyrics, HD cover images and checking for updates.'),
  FaqEntry('Why does Dhunn ask for microphone permission?',
      'Only for the Fluid Beat background: the app listens to the music\'s beat (not your voice) to animate the background. Nothing is ever recorded or sent anywhere.'),
  FaqEntry('How do I update Dhunn?',
      'When a new version is released, Dhunn shows an update message. You can also check any time in Settings → Updates & FAQs → Check for updates.'),
  FaqEntry('My songs are not showing up. What do I do?',
      'Make sure you allowed the Music & audio permission, then go to Settings → My Library and scan your device again.'),
  FaqEntry('Lyrics are missing for a song. Can I add my own?',
      'Yes. Open the song, tap the edit (pencil) icon near the lyrics, and pick a lyrics file or write/paste your own. Your lyrics are saved and used offline.'),
  FaqEntry('Does Dhunn collect my personal data?',
      'No. There is no account, no sign-up and no tracking. Your music and your data never leave your phone.'),
  FaqEntry('How do I change the album art style?',
      'While a song is playing, tap the style icon at the top of the player — or go to Settings → Player & Lyrics → Album art style. There are 50+ styles with live previews.'),
];

class UpdateService {
  static const _media = MethodChannel('nova/media');

  /// Fetches and parses update.json (cache-busted; GitHub raw
  /// caches for a few minutes otherwise). Returns null on any
  /// failure — callers treat that as "no information", never an
  /// error worth bothering the user with.
  static Future<UpdateInfo?> fetch() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final bust = DateTime.now().millisecondsSinceEpoch ~/ 60000;
      final req = await client.getUrl(Uri.parse('$kUpdateJsonUrl?t=$bust'));
      req.headers.set(HttpHeaders.userAgentHeader,
          'Dhunn/$kAppVersionName (Flutter; update check)');
      final resp = await req.close().timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;
      final body = await resp.transform(utf8.decoder).join();
      final j = jsonDecode(body);
      if (j is! Map<String, dynamic>) return null;
      if (j.isEmpty) return null; // file not filled in yet
      return UpdateInfo.fromJson(j);
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Opens the APK / download link in the browser.
  static Future<bool> openDownload(String url) async {
    if (url.isEmpty) return false;
    try {
      return await _media.invokeMethod<bool>('openUrl', {'url': url}) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
