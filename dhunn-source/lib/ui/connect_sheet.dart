import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../services/player.dart';
import '../services/sys.dart';

/// Connect-device sheet (v2.33, his request — modelled on the
/// sheet he screenshotted from another player): CONTROLS tab =
/// this phone + live volume + Wi-Fi/Bluetooth state chips;
/// DEVICES tab = nearby-device discovery state and the paired
/// Bluetooth devices. Radio state and paired devices come from
/// the native "nova/sys" channel; the turn-on buttons open the
/// system panels (Android does not let apps flip the radios).
void showConnectSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _ConnectSheet(),
  );
}

class _ConnectSheet extends StatefulWidget {
  const _ConnectSheet();
  @override
  State<_ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends State<_ConnectSheet> {
  int _tab = 0; // 0 Controls, 1 Devices
  bool? _wifi;
  bool? _bt;
  List<Map<String, String>> _paired = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final w = await SysInfo.wifiEnabled();
    final b = await SysInfo.bluetoothEnabled();
    var paired = <Map<String, String>>[];
    if (b) {
      // Paired-device names need the runtime permission (12+).
      try {
        await Permission.bluetoothConnect.request();
      } catch (_) {}
      paired = await SysInfo.pairedDevices();
    }
    if (mounted) {
      setState(() {
        _wifi = w;
        _bt = b;
        _paired = paired;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final cs = Theme.of(context).colorScheme;
    final bothOff = _wifi == false && _bt == false;
    return SizedBox(
      height: MediaQuery.of(context).size.height * .78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 14),
        child: Column(children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Connect device',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(children: [
              if (_tab == 0) ...[
                _thisPhoneCard(context, player, cs),
                const SizedBox(height: 18),
                Row(children: [
                  const Text('Connectivity',
                      style: TextStyle(
                          fontSize: 16.5, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.refresh, size: 21),
                      tooltip: 'Refresh',
                      onPressed: _refresh),
                ]),
                Text(
                    bothOff
                        ? 'Turn on Wi-Fi or Bluetooth'
                        : 'Radio state on this phone',
                    style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _radioChip(
                          context,
                          _wifi == true ? Icons.wifi : Icons.wifi_off,
                          'Wi-Fi',
                          _wifi,
                          () async {
                            await SysInfo.openWifi();
                            Future.delayed(
                                const Duration(seconds: 1), _refresh);
                          })),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _radioChip(
                          context,
                          _bt == true
                              ? Icons.bluetooth
                              : Icons.bluetooth_disabled,
                          'Bluetooth',
                          _bt,
                          () async {
                            await SysInfo.openBluetooth();
                            Future.delayed(
                                const Duration(seconds: 1), _refresh);
                          })),
                ]),
              ] else ...[
                Row(children: [
                  const Text('Nearby devices',
                      style: TextStyle(
                          fontSize: 16.5, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.refresh, size: 21),
                      tooltip: 'Refresh',
                      onPressed: _refresh),
                ]),
                if (bothOff)
                  _connectionsOffCard(context, cs)
                else ...[
                  if (_paired.isNotEmpty) ...[
                    const Text('Paired Bluetooth devices',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                    const SizedBox(height: 6),
                    for (final d in _paired)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                            backgroundColor: cs.primary.withOpacity(.15),
                            child: Icon(Icons.bluetooth,
                                color: cs.primary, size: 20)),
                        title: Text(
                            (d['name'] ?? '').isEmpty
                                ? 'Bluetooth device'
                                : d['name']!,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(d['address'] ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => SysInfo.openBluetooth(),
                      ),
                  ] else ...[
                    const SizedBox(height: 8),
                    const Text(
                        'No paired Bluetooth devices to show. Pair a speaker or headphones in Bluetooth settings and it will appear here.',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                        onPressed: () => SysInfo.openBluetooth(),
                        child: const Text('Open Bluetooth settings')),
                  ],
                  if (_wifi == true) ...[
                    const SizedBox(height: 14),
                    const Text(
                        'Wi-Fi is on. Dhunn plays on this phone — speakers and headphones connect over Bluetooth.',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                  ],
                ],
              ],
            ]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(.6),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(children: [
              _segment(context, 0, Icons.settings_remote, 'CONTROLS', cs),
              _segment(context, 1, Icons.devices, 'DEVICES', cs),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _segment(BuildContext context, int i, IconData icon, String label,
      ColorScheme cs) {
    final sel = _tab == i;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: sel ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 19, color: sel ? Colors.white : cs.onSurface),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: .6,
                    color: sel ? Colors.white : cs.onSurface)),
          ]),
        ),
      ),
    );
  }

  Widget _thisPhoneCard(
      BuildContext context, PlayerService player, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(.13),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(children: [
        Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: cs.primary.withOpacity(.18),
            child: Icon(Icons.headphones, color: cs.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('This phone',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text('Local playback • ${player.playing ? 'Playing' : 'Paused'}',
                style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
          ]),
        ]),
        const SizedBox(height: 8),
        StreamBuilder<double>(
          stream: player.player.volumeStream,
          initialData: player.player.volume,
          builder: (_, snap) {
            final vol = (snap.data ?? 1.0).clamp(0.0, 1.0);
            return Column(children: [
              Row(children: [
                const Text('Phone volume', style: TextStyle(fontSize: 13.5)),
                const Spacer(),
                Text('${(vol * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
              ]),
              Slider(
                value: vol,
                onChanged: (v) => player.setVolume(v),
              ),
            ]);
          },
        ),
      ]),
    );
  }

  Widget _radioChip(BuildContext context, IconData icon, String label,
      bool? on, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: on == true
                ? cs.primary.withOpacity(.18)
                : cs.onSurface.withOpacity(.08),
            child: Icon(icon,
                size: 19, color: on == true ? cs.primary : Colors.grey),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
            Text(on == null ? '…' : (on ? 'On' : 'Off'),
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ]),
      ),
    );
  }

  Widget _connectionsOffCard(BuildContext context, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 22),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(alignment: Alignment.center, children: [
            Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withOpacity(.10))),
            Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withOpacity(.16))),
            Container(
                width: 50,
                height: 50,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: cs.primary)),
          ]),
        ),
        const SizedBox(height: 16),
        const Text('Connections are off',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
            'Turn on Wi-Fi or Bluetooth to discover nearby devices',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Colors.grey)),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () async {
            await SysInfo.openWifi();
            Future.delayed(const Duration(seconds: 1), _refresh);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            child: Text('Turn on Wi-Fi'),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () async {
            await SysInfo.openBluetooth();
            Future.delayed(const Duration(seconds: 1), _refresh);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            child: Text('Open Bluetooth'),
          ),
        ),
      ]),
    );
  }
}
