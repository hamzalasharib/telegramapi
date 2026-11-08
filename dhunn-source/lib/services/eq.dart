import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Native equalizer service — talks to the Kotlin `nova/eq` channel,
/// which attaches real Android audiofx effects (Equalizer, BassBoost,
/// LoudnessEnhancer) to the audio session of the playing track.
///
/// v2.0's just_audio FX pipeline never became audible on the user's
/// device; session-level native effects are the reliable route and they
/// keep working no matter how the player pipeline is configured.
class EqService extends ChangeNotifier {
  static final EqService instance = EqService._();
  EqService._() {
    _loadPrefs();
  }

  static const _ch = MethodChannel('nova/eq');

  bool attached = false;
  bool failed = false;
  int bandCount = 0;
  int minMb = -1500;
  int maxMb = 1500;
  List<int> freqsHz = [];

  bool enabled = true;
  List<int> gainsMb = []; // per band, millibels
  String preset = 'Custom';
  int bass = 0; // 0..1000 strength (the SET value)
  int loudMb = 0; // 0..1500 millibels target gain (the SET value)
  int virt = 0; // 0..1000 strength (the SET value)
  bool virtSupported = false;
  // Knob on/off toggles (PixelPlayer-style, v2.22): the effective
  // value pushed to the device is the set value when ON, else 0.
  bool bassOn = true;
  bool loudOn = true;
  bool virtOn = true;
  // User-saved custom presets (v2.22): name -> per-band gains (mB).
  Map<String, List<int>> customPresets = {};

  int _sessionId = -1;

  /// Presets as normalized gains (-1..1) for 5 bands; mapped onto the
  /// device's band count and level range when applied.
  static const presets = <String, List<double>>{
    'Normal': [0, 0, 0, 0, 0],
    'Bass': [0.85, 0.6, 0.25, 0, 0],
    'Treble': [0, 0, 0.25, 0.6, 0.85],
    'Vocal': [-0.25, 0.15, 0.75, 0.6, 0.1],
    'Rock': [0.6, 0.35, -0.1, 0.45, 0.7],
    'Pop': [-0.15, 0.3, 0.55, 0.3, -0.1],
    'Jazz': [0.45, 0.3, 0.1, 0.35, 0.5],
    'Dance': [0.9, 0.55, 0.15, 0.3, 0.45],
    'Classical': [0.3, 0.2, 0, 0.25, 0.4],
    'Flat': [0, 0, 0, 0, 0],
  };

  Future<void> _loadPrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      enabled = sp.getBool('eqEnabled') ?? true;
      preset = sp.getString('eqPreset') ?? 'Custom';
      bass = sp.getInt('eqBass') ?? 0;
      loudMb = sp.getInt('eqLoud') ?? 0;
      virt = sp.getInt('eqVirt') ?? 0;
      bassOn = sp.getBool('eqBassOn') ?? true;
      loudOn = sp.getBool('eqLoudOn') ?? true;
      virtOn = sp.getBool('eqVirtOn') ?? true;
      try {
        final cp = jsonDecode(sp.getString('eqCustomPresets') ?? '{}')
            as Map<String, dynamic>;
        customPresets = cp.map((k, v) => MapEntry(
            k, (v as List).map((e) => (e as num).toInt()).toList()));
      } catch (_) {}
      gainsMb = (sp.getStringList('eqGains') ?? [])
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool('eqEnabled', enabled);
      await sp.setString('eqPreset', preset);
      await sp.setInt('eqBass', bass);
      await sp.setInt('eqLoud', loudMb);
      await sp.setInt('eqVirt', virt);
      await sp.setBool('eqBassOn', bassOn);
      await sp.setBool('eqLoudOn', loudOn);
      await sp.setBool('eqVirtOn', virtOn);
      await sp.setString('eqCustomPresets', jsonEncode(customPresets));
      await sp.setStringList('eqGains', gainsMb.map((e) => '$e').toList());
    } catch (_) {}
  }

  int _gainForBand(int band) =>
      gainsMb.length == bandCount && band < gainsMb.length ? gainsMb[band] : 0;

  /// Called by PlayerService whenever the audio session changes.
  Future<void> attach(int sessionId) async {
    if (sessionId == _sessionId && attached) return;
    _sessionId = sessionId;
    try {
      final res = await _ch.invokeMapMethod<String, dynamic>('attach', {'sessionId': sessionId});
      if (res == null) {
        failed = true;
        attached = false;
        notifyListeners();
        return;
      }
      virtSupported = (res['virt'] as bool?) ?? false;
      bandCount = (res['bands'] as int?) ?? 0;
      minMb = (res['min'] as int?) ?? -1500;
      maxMb = (res['max'] as int?) ?? 1500;
      freqsHz = ((res['freqs'] as List?) ?? []).map((e) => (e as num).toInt()).toList();
      if (gainsMb.length != bandCount) {
        gainsMb = List.filled(bandCount, 0);
        if (preset != 'Custom' && presets.containsKey(preset)) {
          _applyPresetValues(preset);
        }
      }
      attached = true;
      failed = false;
      await _pushAll();
      notifyListeners();
    } catch (_) {
      failed = true;
      attached = false;
      notifyListeners();
    }
  }

  void _applyPresetValues(String name) {
    final prof = presets[name]!;
    for (var i = 0; i < bandCount; i++) {
      final n = prof[(i * prof.length / bandCount).floor().clamp(0, prof.length - 1)];
      gainsMb[i] = (n * (n >= 0 ? maxMb : -minMb)).round().clamp(minMb, maxMb);
    }
  }

  Future<void> _pushAll() async {
    if (!attached) return;
    try {
      // v2.30 VOLUME-SPIKE FIX: push every VALUE first and switch
      // the master enable LAST. A freshly created native Equalizer
      // sits DISABLED with the OEM's own default curve inside;
      // enabling it first (the old order) made that default curve
      // blast at full volume for a moment, then the band/bass/
      // loudness calls walked the sound back DOWN to the user's
      // real settings — heard as "volume jumps up, then auto
      // down" on the first song. Values set while disabled are
      // stored by the effect and only become audible at enable,
      // so now there is exactly ONE step: plain -> final sound.
      for (var i = 0; i < bandCount; i++) {
        await _ch.invokeMethod('setBand', {'band': i, 'level': _gainForBand(i)});
      }
      await _ch.invokeMethod('setBass', {'strength': bassOn ? bass : 0});
      await _ch.invokeMethod('setLoud', {'gain': loudOn ? loudMb : 0});
      await _ch.invokeMethod('setVirt', {'strength': virtOn ? virt : 0});
      await _ch.invokeMethod('setEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  Future<void> setEnabled(bool v) async {
    enabled = v;
    await _savePrefs();
    if (attached) {
      try {
        await _ch.invokeMethod('setEnabled', {'enabled': v});
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setBand(int band, int levelMb) async {
    if (bandCount == 0) return;
    if (gainsMb.length != bandCount) gainsMb = List.filled(bandCount, 0);
    gainsMb[band] = levelMb.clamp(minMb, maxMb);
    preset = 'Custom';
    await _savePrefs();
    if (attached) {
      try {
        await _ch.invokeMethod('setBand', {'band': band, 'level': gainsMb[band]});
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> applyPreset(String name) async {
    preset = name;
    if (bandCount > 0) {
      if (gainsMb.length != bandCount) gainsMb = List.filled(bandCount, 0);
      _applyPresetValues(name);
      if (attached) {
        for (var i = 0; i < bandCount; i++) {
          try {
            await _ch.invokeMethod('setBand', {'band': i, 'level': gainsMb[i]});
          } catch (_) {}
        }
      }
    }
    await _savePrefs();
    notifyListeners();
  }

  Future<void> setBass(int strength) async {
    bass = strength.clamp(0, 1000);
    if (bass > 0) bassOn = true;
    await _savePrefs();
    if (attached) {
      try {
        await _ch.invokeMethod('setBass', {'strength': bassOn ? bass : 0});
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setLoud(int gainMb) async {
    loudMb = gainMb.clamp(0, 1500);
    if (loudMb > 0) loudOn = true;
    await _savePrefs();
    if (attached) {
      try {
        await _ch.invokeMethod('setLoud', {'gain': loudOn ? loudMb : 0});
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setVirt(int strength) async {
    virt = strength.clamp(0, 1000);
    if (virt > 0) virtOn = true;
    await _savePrefs();
    if (attached) {
      try {
        await _ch.invokeMethod('setVirt', {'strength': virtOn ? virt : 0});
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setKnobOn(String which, bool on) async {
    int eff;
    String method;
    Map<String, int> args;
    switch (which) {
      case 'bass':
        bassOn = on; eff = on ? bass : 0; method = 'setBass'; args = {'strength': eff};
      case 'virt':
        virtOn = on; eff = on ? virt : 0; method = 'setVirt'; args = {'strength': eff};
      default:
        loudOn = on; eff = on ? loudMb : 0; method = 'setLoud'; args = {'gain': eff};
    }
    await _savePrefs();
    if (attached) {
      try {
        await _ch.invokeMethod(method, args);
      } catch (_) {}
    }
    notifyListeners();
  }

  // ---- Custom presets (v2.22) ----
  Future<void> saveCustomPreset(String name) async {
    name = name.trim();
    if (name.isEmpty || bandCount == 0) return;
    if (gainsMb.length != bandCount) gainsMb = List.filled(bandCount, 0);
    customPresets[name] = List<int>.of(gainsMb);
    preset = name;
    await _savePrefs();
    notifyListeners();
  }

  Future<void> applyCustomPreset(String name) async {
    final g = customPresets[name];
    if (g == null || bandCount == 0) return;
    preset = name;
    if (gainsMb.length != bandCount) gainsMb = List.filled(bandCount, 0);
    for (var i = 0; i < bandCount; i++) {
      gainsMb[i] = (i < g.length ? g[i] : 0).clamp(minMb, maxMb);
    }
    if (attached) {
      for (var i = 0; i < bandCount; i++) {
        try {
          await _ch.invokeMethod('setBand', {'band': i, 'level': gainsMb[i]});
        } catch (_) {}
      }
    }
    await _savePrefs();
    notifyListeners();
  }

  Future<void> deleteCustomPreset(String name) async {
    customPresets.remove(name);
    if (preset == name) preset = 'Custom';
    await _savePrefs();
    notifyListeners();
  }
}
