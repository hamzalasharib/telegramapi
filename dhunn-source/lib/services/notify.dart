import 'package:flutter/services.dart';

/// Progress notifications posted NATIVELY over the `nova/notify`
/// channel (v2.19) — deliberately no extra Dart plugin, so the APK
/// does not grow for this. Used by the bulk HD-cover job so the user
/// can leave Settings and still watch progress in the shade.
/// Every call swallows errors: a missing notification must never
/// break the job itself.
class ProgressNotify {
  static const _ch = MethodChannel('nova/notify');

  static Future<void> progress(
      {required int id,
      required String title,
      required String text,
      required int done,
      required int total}) async {
    try {
      await _ch.invokeMethod('progress',
          {'id': id, 'title': title, 'text': text, 'done': done, 'total': total});
    } catch (_) {}
  }

  static Future<void> done(
      {required int id, required String title, required String text}) async {
    try {
      await _ch.invokeMethod('done', {'id': id, 'title': title, 'text': text});
    } catch (_) {}
  }

  /// A one-off alert with its own higher-importance native
  /// channel (v2.21) — new-song alerts should actually be seen,
  /// not sit silently like progress notifications.
  static Future<void> alert(
      {required int id, required String title, required String text}) async {
    try {
      await _ch.invokeMethod('alert', {'id': id, 'title': title, 'text': text});
    } catch (_) {}
  }

  static Future<void> cancel(int id) async {
    try {
      await _ch.invokeMethod('cancel', {'id': id});
    } catch (_) {}
  }
}
