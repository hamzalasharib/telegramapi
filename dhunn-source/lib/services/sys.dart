import 'package:flutter/services.dart';

/// System bridges for Drive Mode + the Connect-device sheet
/// (v2.33), served natively by the "nova/sys" channel in
/// MainActivity: keep-screen-on, Wi-Fi/Bluetooth radio state,
/// paired Bluetooth devices and the system settings panels.
class SysInfo {
  static const _ch = MethodChannel('nova/sys');

  static Future<void> keepScreenOn(bool on) async {
    try {
      await _ch.invokeMethod('keepScreenOn', on);
    } catch (_) {}
  }

  static Future<bool> wifiEnabled() async {
    try {
      return await _ch.invokeMethod<bool>('wifiEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> bluetoothEnabled() async {
    try {
      return await _ch.invokeMethod<bool>('bluetoothEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Paired (bonded) Bluetooth devices: [{name, address}].
  /// Names need the BLUETOOTH_CONNECT runtime permission on
  /// Android 12+; without it the list comes back empty.
  static Future<List<Map<String, String>>> pairedDevices() async {
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('pairedDevices');
      return (raw ?? [])
          .map((e) => (e as Map)
              .map((k, v) => MapEntry(k.toString(), v.toString())))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> openWifi() async {
    try {
      await _ch.invokeMethod('openWifi');
    } catch (_) {}
  }

  static Future<void> openBluetooth() async {
    try {
      await _ch.invokeMethod('openBluetooth');
    } catch (_) {}
  }
}
