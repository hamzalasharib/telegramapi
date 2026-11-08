import 'package:flutter/services.dart';

/// Picks a custom Now Playing background picture via the native
/// document picker (channel `nova/bg`); the image is copied into the
/// app's private files, so no storage permission is needed afterwards.
class BgPicker {
  static const _ch = MethodChannel('nova/bg');
  static Future<String?> pick() async {
    try {
      return await _ch.invokeMethod<String>('pick');
    } catch (_) {
      return null;
    }
  }
}

/// Picks a lyrics text file (.lrc / .txt) via the native picker
/// (channel `nova/files`); content is copied into app files.
class TextFilePicker {
  static const _ch = MethodChannel('nova/files');
  static Future<String?> pickPath() async {
    try {
      return await _ch.invokeMethod<String>('pickText');
    } catch (_) {
      return null;
    }
  }
}

/// Picks a FOLDER via the native document tree picker (channel
/// `nova/files`); the native side converts the tree URI into a real
/// filesystem path (primary storage / SD card) so MediaStore paths
/// can be matched against it (v2.20 "songs from one folder only").
class FolderPicker {
  static const _ch = MethodChannel('nova/files');
  static Future<String?> pick() async {
    try {
      return await _ch.invokeMethod<String>('pickFolder');
    } catch (_) {
      return null;
    }
  }
}
