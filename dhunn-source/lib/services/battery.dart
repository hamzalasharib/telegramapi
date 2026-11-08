import 'package:flutter/services.dart';

/// Background-playback survival (v2.19.1): on aggressive phones
/// (OPPO/ColorOS, vivo, Xiaomi...) Android kills the music process
/// after a while in the background. The real fixes live in system
/// settings, so these helpers open them natively over the existing
/// `nova/media` channel: battery-optimisation exemption and the
/// vendor auto-start screen. Every call swallows errors.
class BatteryFix {
  static const _ch = MethodChannel('nova/media');

  static Future<bool> isExempt() async {
    try {
      return await _ch.invokeMethod<bool>('batteryExempt') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestExempt() async {
    try {
      return await _ch.invokeMethod<bool>('requestBatteryExempt') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openAutoStart() async {
    try {
      return await _ch.invokeMethod<bool>('openAutoStart') ?? false;
    } catch (_) {
      return false;
    }
  }
}
