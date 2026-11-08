import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../core/store.dart';
import '../services/player.dart';
import '../services/sys.dart';
import 'widgets.dart';

/// Drive Mode (v2.33, his request): a distraction-free player
/// for the car — huge artwork, giant transport controls, shuffle
/// / repeat / favourite within thumb reach, and the screen stays
/// awake while the mode is open. Everything drives the same
/// PlayerService as the normal player.
class DriveModeScreen extends StatefulWidget {
  const DriveModeScreen({super.key});
  @override
  State<DriveModeScreen> createState() => _DriveModeScreenState();
}

class _DriveModeScreenState extends State<DriveModeScreen> {
  @override
  void initState() {
    super.initState();
    SysInfo.keepScreenOn(true);
  }

  @override
  void dispose() {
    SysInfo.keepScreenOn(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    context.watch<AppStore>(); // rebuild on theme/store changes
    final accent = Theme.of(context).colorScheme.primary;
    final item = player.current;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B14),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
          child: Column(children: [
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withOpacity(.45)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.directions_car, size: 17, color: accent),
                  const SizedBox(width: 6),
                  Text('DRIVE MODE',
                      style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4)),
                ]),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Exit drive mode',
                iconSize: 30,
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
            if (item == null)
              const Expanded(
                child: Center(
                  child: Text('Nothing is playing yet.\nPick a song first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 17)),
                ),
              )
            else ...[
              const Spacer(),
              artwork(item,
                  size: MediaQuery.of(context).size.width * .58,
                  radius: 26),
              const SizedBox(height: 26),
              Text(item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(item.artist.isEmpty ? 'Unknown artist' : item.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 17)),
              const SizedBox(height: 22),
              StreamBuilder<Duration>(
                stream: player.player.positionStream,
                builder: (_, snap) {
                  final pos = snap.data ?? player.player.position;
                  final dur = player.player.duration ?? item.duration;
                  final frac = dur.inMilliseconds > 0
                      ? (pos.inMilliseconds / dur.inMilliseconds)
                          .clamp(0.0, 1.0)
                      : 0.0;
                  return Column(children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 7,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 13),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 24),
                      ),
                      child: Slider(
                        value: frac,
                        activeColor: accent,
                        inactiveColor: Colors.white24,
                        onChanged: dur.inMilliseconds == 0
                            ? null
                            : (f) => player.seek(Duration(
                                milliseconds:
                                    (f * dur.inMilliseconds).round())),
                      ),
                    ),
                    Row(children: [
                      Text(formatDuration(pos),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 14)),
                      const Spacer(),
                      Text(formatDuration(dur),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 14)),
                    ]),
                  ]);
                },
              ),
              const SizedBox(height: 10),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      iconSize: 30,
                      icon: Icon(Icons.shuffle,
                          color:
                              player.shuffleOn ? accent : Colors.white54),
                      onPressed: player.toggleShuffle,
                    ),
                    IconButton(
                      iconSize: 58,
                      icon: const Icon(Icons.skip_previous_rounded,
                          color: Colors.white),
                      onPressed: player.previous,
                    ),
                    Material(
                      color: accent,
                      shape: const CircleBorder(),
                      elevation: 10,
                      shadowColor: Colors.black54,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: player.toggle,
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: Icon(
                              player.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 56,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    IconButton(
                      iconSize: 58,
                      icon: const Icon(Icons.skip_next_rounded,
                          color: Colors.white),
                      onPressed: player.next,
                    ),
                    IconButton(
                      iconSize: 30,
                      icon: Icon(
                          player.loopMode == LoopMode.one
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                          color: player.loopMode != LoopMode.off
                              ? accent
                              : Colors.white54),
                      onPressed: player.cycleLoop,
                    ),
                  ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                FavHeartButton(item: item),
                const SizedBox(width: 26),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                  label: const Text('Exit drive mode',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 15)),
                ),
              ]),
              const Spacer(),
            ],
          ]),
        ),
      ),
    );
  }
}
