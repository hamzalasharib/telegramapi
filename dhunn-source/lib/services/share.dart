import 'package:flutter/services.dart';

/// Share a song FILE through the system share sheet (v2.23),
/// via the native `nova/files` shareFile method (FileProvider).
class ShareService {
  static const _ch = MethodChannel('nova/files');

  static Future<bool> shareSong(String path, String title) async {
    if (path.isEmpty) return false;
    try {
      return await _ch.invokeMethod<bool>(
              'shareFile', {'path': path, 'title': title}) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
