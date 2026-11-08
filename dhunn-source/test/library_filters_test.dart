import 'package:flutter_test/flutter_test.dart';
import 'package:nova_player/core/models.dart';
import 'package:nova_player/core/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

MediaItem song(String id, String path, int ms) => MediaItem.fromJson({
      'id': id,
      'title': id,
      'source': 'content://media/$id',
      'filePath': path,
      'isLocal': true,
      'durationMs': ms,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('skip short clips hides under-threshold audio only', () async {
    final store = AppStore();
    store.skipShortAudio = true;
    store.skipShortSec = 30;
    await store.setLibrary([
      song('voice10', '/storage/emulated/0/WhatsApp/voice.opus', 10000),
      song('voice29', '/storage/emulated/0/WhatsApp/voice2.opus', 29000),
      song('exact30', '/storage/emulated/0/Music/a.mp3', 30000),
      song('song200', '/storage/emulated/0/Music/b.mp3', 200000),
      song('unknown0', '/storage/emulated/0/Music/c.mp3', 0),
    ], const []);
    expect(store.localAudio.map((e) => e.id),
        ['exact30', 'song200', 'unknown0']);
    expect(store.hiddenByFilters, 2);
  });

  test('folder filter keeps only songs under the chosen folder', () async {
    final store = AppStore();
    store.musicFolder = '/storage/emulated/0/Music';
    await store.setLibrary([
      song('in', '/storage/emulated/0/Music/x.mp3', 200000),
      song('out', '/storage/emulated/0/Download/y.mp3', 200000),
    ], const []);
    expect(store.localAudio.map((e) => e.id), ['in']);
    expect(store.hiddenByFilters, 1);
  });

  test('filters off keeps everything', () async {
    final store = AppStore();
    await store.setLibrary([
      song('v', '/storage/emulated/0/WhatsApp/v.opus', 5000),
    ], const []);
    expect(store.localAudio.length, 1);
    expect(store.hiddenByFilters, 0);
  });
}
