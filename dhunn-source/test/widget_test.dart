import 'package:flutter_test/flutter_test.dart';
import 'package:nova_player/core/l10n.dart';
import 'package:nova_player/core/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nova_player/core/store.dart';
import 'package:nova_player/services/lyrics_fx.dart';
import 'package:nova_player/services/api.dart';
import 'package:nova_player/services/beat.dart';
import 'package:nova_player/services/update.dart';
import 'package:nova_player/ui/widgets.dart';

void main() {
  test('LRC parser extracts timed lines in order', () {
    const lrc = '''
[00:12.50]Second line here
[00:05.00]First line
[00:20.75]
[01:02.00]Minute line
not a lyric line
''';
    final lines = Api.parseLrc(lrc);
    expect(lines.length, 4);
    expect(lines.first.text, 'First line');
    expect(lines.first.time, const Duration(seconds: 5));
    expect(lines[1].time, const Duration(seconds: 12, milliseconds: 500));
    expect(lines[2].text, '');
    expect(lines[3].time, const Duration(minutes: 1, seconds: 2));
  });

  test('MediaItem JSON round-trip keeps core fields', () {
    const item = MediaItem(
      id: 'x1', title: 'Song', artist: 'Artist', album: 'Album',
      source: '/music/song.mp3', isLocal: true,
      duration: Duration(minutes: 3, seconds: 5),
    );
    final back = MediaItem.fromJson(item.toJson());
    expect(back.id, 'x1');
    expect(back.title, 'Song');
    expect(back.duration, const Duration(minutes: 3, seconds: 5));
    expect(back.isLocal, isTrue);
  });

  test('LyricsData hasSynced requires lines', () {
    expect(const LyricsData().hasSynced, isFalse);
    expect(
        const LyricsData(synced: [LrcLine(Duration.zero, 'a')]).hasSynced, isTrue);
  });

  test('Localization is English only', () {
    expect(L.supported.keys, ['en']);
    const l = L('en');
    expect(l.t('home'), 'Home');
    expect(l.t('settings'), 'Settings');
    expect(L.isRtl('ur'), isFalse);
  });

  test('LyricsData.dataFrom rebuilds synced lines and keeps raw text', () {
    const raw = '[00:01.00]One\n[00:02.50]Two';
    final d = Api.dataFrom(syncedRaw: raw);
    expect(d.hasSynced, isTrue);
    expect(d.rawSynced, raw);
    expect(d.plain, 'One\nTwo');
    expect(d.synced!.length, 2);
    final p = Api.dataFrom(plain: 'just text');
    expect(p.plain, 'just text');
    expect(p.hasSynced, isFalse);
  });

  test('AppStore lyrics cache stores and returns raw lyrics', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final s = AppStore();
    expect(s.cachedLyricsRaw('t1'), isNull);
    s.saveLyricsCache('t1', plain: 'One\nTwo', syncedRaw: '[00:01.00]One\n[00:02.50]Two');
    final c = s.cachedLyricsRaw('t1');
    expect(c, isNotNull);
    expect(c!.$1, 'One\nTwo');
    expect(c.$2, contains('[00:02.50]Two'));
    expect(s.cachedLyricsCount, 1);
    s.saveLyricsCache('t2'); // empty -> ignored
    expect(s.cachedLyricsCount, 1);
  });

  test('LyricsFx: 40 curated presets, Blur Focus lives at index 2', () {
    expect(LyricsFx.presets.length, 40);
    expect(LyricsFx.of(2).base, 3); // Blur Focus
    expect(LyricsFx.of(2).name, contains('Blur Focus'));
    expect(LyricsFx.of(2).blur, greaterThan(0));
    expect(LyricsFx.of(1).wordKaraoke, isTrue); // Karaoke Words
    expect(LyricsFx.of(8).base, 11); // Neon Sign
    expect(LyricsFx.of(30).outline, isTrue); // new Outline effect
    final names = LyricsFx.presets.map((f) => f.name).toSet();
    expect(names.length, 40); // every preset name unique
    // v2.33 migration from the old base*10+colourway indices
    expect(LyricsFx.migrateIndex(30), 2); // old Blur Focus (base 3, cw 0)
    expect(LyricsFx.migrateIndex(34), 2); // old base 3 cw 4 -> base entry
    expect(LyricsFx.migrateIndex(112), 24); // old Neon Emerald (base 11, cw 2)
    expect(LyricsFx.migrateIndex(0), 1); // old Karaoke Words (base 0, cw 0)
  });

  test('ChangelogEntry falls back to versionName/notes shape', () {
    final e = ChangelogEntry.fromJson(const {
      'versionName': '9.9.9',
      'versionCode': 99,
      'notes': 'Something changed in this version.',
    });
    expect(e.version, '9.9.9');
    expect(e.changes, ['Something changed in this version.']);
  });

  test('BeatService.smooth attacks fast and decays slowly', () {
    // attack: jumps most of the way toward a loud beat instantly
    expect(BeatService.smooth(0, 1), greaterThan(0.6));
    // decay: a quiet frame after a loud one keeps most of the level
    expect(BeatService.smooth(1, 0), greaterThan(0.8));
    expect(BeatService.smooth(1, 0), lessThan(1));
    // steady state converges
    var v = 0.0;
    for (var i = 0; i < 40; i++) {
      v = BeatService.smooth(v, 0.5);
    }
    expect(v, closeTo(0.5, 0.05));
  });

  test('AppStore cover upgrade applies to the library item', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final s = AppStore();
    const item = MediaItem(id: 'c1', title: 'Song', artist: 'A', source: '/x.mp3', isLocal: true);
    s.localAudio = [item];
    s.setCoverUpgrade('c1', '/data/covers/cover_c1.jpg');
    expect(s.localAudio.first.artworkUrl, '/data/covers/cover_c1.jpg');
    expect(s.coverUpgrades['c1'], '/data/covers/cover_c1.jpg');
  });

  test('setLibrary: auto pass merges (never removes), manual replaces', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final s = AppStore();
    MediaItem song(String id, String path) => MediaItem(
        id: id, title: 'Song $id', artist: 'A', source: 'content://$id',
        filePath: path, isLocal: true,
        duration: const Duration(minutes: 3));
    final a = song('a', '/music/a.mp3');
    final b = song('b', '/music/b.mp3');
    final c = song('c', '/music/c.mp3');
    await s.setLibrary([a, b], const [], authoritative: true);
    expect(s.localAudio.length, 2);
    // A partial auto pass (only c) must ADD c and keep a + b.
    await s.setLibrary([c], const []);
    expect(s.localAudio.length, 3);
    expect(s.localAudio.map((e) => e.id).toSet(), {'a', 'b', 'c'});
    // An authoritative (manual) scan replaces wholesale.
    await s.setLibrary([c], const [], authoritative: true);
    expect(s.localAudio.length, 1);
    expect(s.localAudio.single.id, 'c');
  });

  test('formatDuration renders m:ss and h:mm:ss', () {
    expect(formatDuration(const Duration(seconds: 65)), '1:05');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    expect(formatBytes(2048), '2.0 KB');
  });
  test('UpdateInfo parses the shipped update.json shape', () {
    final info = UpdateInfo.fromJson({
      'latest': {
        'versionName': '2.17.0',
        'versionCode': kAppVersionCode + 1,
        'apkUrl': 'https://example.com/app.apk',
        'notes': 'hi',
        'forceUpdate': true,
      },
      'changelog': [
        {
          'version': '2.17.0',
          'date': '2026-11-03',
          'changes': ['a', 'b']
        }
      ],
      'faqs': [
        {'q': 'Q?', 'a': 'A.'}
      ],
    });
    expect(info.updateAvailable, isTrue); // fixture is one above the app
    expect(info.forceUpdate, isTrue);
    expect(info.changelog.single.changes, ['a', 'b']);
    expect(info.faqs.single.q, 'Q?');
    final same = UpdateInfo.fromJson({
      'latest': {'versionCode': kAppVersionCode}
    });
    expect(same.updateAvailable, isFalse);
  });
}
