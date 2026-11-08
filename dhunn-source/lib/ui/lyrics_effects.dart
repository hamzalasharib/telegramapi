import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/store.dart';
import '../services/lyrics_fx.dart';

/// Lyrics effects gallery (v2.27): ALL presets in a GRID with a
/// live-styled preview on every card (the user's order — grid,
/// not a list), plus a custom lyrics-colour picker at the top.
/// Opened from the player (✨) and from Settings.
class LyricsEffectsScreen extends StatefulWidget {
  const LyricsEffectsScreen({super.key});
  @override
  State<LyricsEffectsScreen> createState() => _LyricsEffectsScreenState();
}

class _LyricsEffectsScreenState extends State<LyricsEffectsScreen> {
  String _q = '';
  final _gridScroll = ScrollController();
  final _selKey = GlobalKey();

  @override
  void dispose() {
    _gridScroll.dispose();
    super.dispose();
  }

  /// Open scrolled to the SELECTED effect (v2.33, his order —
  /// "seedha ossi par jaaye jo select ho, shuru se na ho"):
  /// estimate the row offset, jump, then snap exactly with
  /// ensureVisible once the card is laid out.
  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_gridScroll.hasClients) return;
      final store = context.read<AppStore>();
      final idx = store.lyricsStyle;
      final w = MediaQuery.of(context).size.width;
      final itemW = (w - 24 - 10) / 2;
      final stride = itemW / 0.92 + 10;
      final target = ((idx ~/ 2) * stride -
              _gridScroll.position.viewportDimension * 0.28)
          .clamp(0.0, _gridScroll.position.maxScrollExtent);
      _gridScroll.jumpTo(target);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _selKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              alignment: 0.25);
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollToSelected();
  }

  static const _colourChoices = <Color>[
    Color(0xFFFFFFFF), Color(0xFF1ED760), Color(0xFF00C2FF), Color(0xFFFF3D71),
    Color(0xFFA259FF), Color(0xFFFFC542), Color(0xFFFF7A18), Color(0xFFFF5C8A),
    Color(0xFF9BE7FF), Color(0xFF00D68F), Color(0xFFFFAA00), Color(0xFF4F7CFF),
    Color(0xFFE93FD8), Color(0xFFE5322D), Color(0xFFFFD93D), Color(0xFF95E1D3),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final accent = Theme.of(context).colorScheme.primary;
    final q = _q.trim().toLowerCase();
    final matches = LyricsFx.presets
        .where((fx) => q.isEmpty || fx.name.toLowerCase().contains(q))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lyrics effects'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${LyricsFx.presets.length} effects — tap to apply',
                style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
          ),
        ),
      ),
      body: Column(children: [
        // Custom lyrics colour (v2.27): Auto = the effect's own
        // colours; any swatch overrides the singing line's colour.
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(children: [
            const Text('Lyrics colour',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _autoChip(store),
                  for (final c in _colourChoices) _swatch(store, c),
                ]),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'Search effects — try "blur", "neon", "gold"…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: matches.isEmpty
              ? const Center(child: Text('No effects match your search.'))
              : GridView.builder(
                  controller: _gridScroll,
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: matches.length,
                  itemBuilder: (_, i) {
                    final fx = matches[i];
                    final index = LyricsFx.presets.indexOf(fx);
                    final selected = store.lyricsStyle == index;
                    return _card(context, store, fx, index, selected, accent);
                  },
                ),
        ),
      ]),
    );
  }

  Widget _autoChip(AppStore store) {
    final sel = store.lyricsColorValue == 0;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: const Text('Auto'),
        selected: sel,
        onSelected: (_) => store.update(() => store.lyricsColorValue = 0),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _swatch(AppStore store, Color c) {
    final sel = store.lyricsColorValue == c.value;
    return GestureDetector(
      onTap: () => store.update(() => store.lyricsColorValue = c.value),
      child: Container(
        width: 26, height: 26,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: c, shape: BoxShape.circle,
          border: Border.all(
              color: sel ? Colors.white : Colors.white24, width: sel ? 2.4 : 1),
          boxShadow: sel ? [BoxShadow(color: c.withOpacity(.6), blurRadius: 8)] : null,
        ),
        child: sel ? const Icon(Icons.check, size: 14, color: Colors.black87) : null,
      ),
    );
  }

  Widget _card(BuildContext context, AppStore store, LyricsFx fx,
      int index, bool selected, Color accent) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      key: selected ? _selKey : null,
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        store.update(() => store.lyricsStyle = index);
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? accent : Colors.white.withOpacity(.06),
              width: selected ? 2 : 1),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _FxPreview(fx: fx, accent: accent, customColor: store.lyricsColorValue)),
          const SizedBox(height: 7),
          Row(children: [
            Expanded(
              child: Text(fx.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      fontSize: 12.5)),
            ),
            if (selected) Icon(Icons.check_circle, color: accent, size: 16),
          ]),
          Text(fx.desc,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
        ]),
      ),
    );
  }

}

/// LIVE preview of one effect (v2.28, his order): the three
/// sample lines keep cycling — each line takes its turn as the
/// singing line with the preset's real styling (pop scale with
/// the bounce curve, blur on the others, pill / gradient / glow,
/// word-by-word karaoke and typewriter approximations), so the
/// user SEES the animation before choosing. Cheap on purpose:
/// text and transforms only, one small controller per card.
class _FxPreview extends StatefulWidget {
  final LyricsFx fx;
  final Color accent;
  final int customColor;
  const _FxPreview({required this.fx, required this.accent, required this.customColor});
  @override
  State<_FxPreview> createState() => _FxPreviewState();
}

class _FxPreviewState extends State<_FxPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _lines = [
    'Previous line of the song',
    'Current singing line',
    'Next line coming up next',
  ];

  @override
  Widget build(BuildContext context) {
    final fx = widget.fx;
    final (ec1, ec2) = fx.colors(widget.accent);
    final c1 = widget.customColor == 0 ? ec1 : Color(widget.customColor);
    final c2 = widget.customColor == 0
        ? ec2
        : Color.lerp(c1, Colors.white, .35)!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C14),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final step = (_c.value * 3).floor() % 3;
          final frac = (_c.value * 3) % 1;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: fx.center
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 5),
                _line(fx, i, step, frac, c1, c2),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _line(LyricsFx fx, int i, int step, double frac, Color c1, Color c2) {
    final text = _lines[i];
    final align = fx.center ? TextAlign.center : TextAlign.left;
    if (i != step) {
      final past = i < step;
      Widget w = Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(
              fontSize: 10.5 * fx.idleScale.clamp(.7, 1.0),
              color: Colors.white
                  .withOpacity(past ? fx.pastOpacity : fx.idleOpacity)));
      if (fx.blur > 0) {
        w = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
                sigmaX: fx.blur * .8, sigmaY: fx.blur * .8),
            child: w);
      }
      if (fx.wave) {
        w = Transform.translate(
            offset: Offset(4 + 2 * (frac - .5), 0), child: w);
      }
      return w;
    }
    // The singing line: pop-in scale over the first part of its
    // turn (bounce curve for bounce presets), then steady.
    final pop = fx.bounce
        ? Curves.easeOutBack.transform(frac.clamp(0, 1))
        : Curves.easeOut.transform((frac * 1.6).clamp(0, 1));
    final scale = 1 + (fx.scale - 1) * pop;
    Widget content;
    if (fx.wordKaraoke) {
      final words = text.split(' ');
      final lit = (frac * words.length).ceil().clamp(1, words.length);
      content = RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        text: TextSpan(children: [
          for (var w = 0; w < words.length; w++)
            TextSpan(
              text: w == 0 ? words[w] : ' ${words[w]}',
              style: TextStyle(
                fontSize: 12 + fx.sizeBoost * .8,
                fontWeight: FontWeight.w800,
                letterSpacing: fx.letterSpacing,
                color: w < lit ? c1 : Colors.white.withOpacity(.4),
              ),
            ),
        ]),
      );
    } else if (fx.typewriter) {
      final shown =
          text.substring(0, (frac * text.length).ceil().clamp(1, text.length));
      content = Text(shown,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(
              fontSize: 12 + fx.sizeBoost * .8,
              fontWeight: FontWeight.w800,
              letterSpacing: fx.letterSpacing,
              color: c1));
    } else if (fx.gradient) {
      content = ShaderMask(
        shaderCallback: (r) => LinearGradient(colors: [c1, c2]).createShader(r),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
            style: TextStyle(
                fontSize: 12 + fx.sizeBoost * .8,
                fontWeight: FontWeight.w800,
                letterSpacing: fx.letterSpacing,
                color: Colors.white)),
      );
    } else if (fx.outline) {
      content = Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(
            fontSize: 12 + fx.sizeBoost * .8,
            fontWeight: FontWeight.w800,
            letterSpacing: fx.letterSpacing,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1
              ..color = c1,
            shadows:
                fx.glow > 0 ? [Shadow(color: c1, blurRadius: fx.glow * .7)] : null,
          ));
    } else {
      content = Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(
            fontSize: 12 + fx.sizeBoost * .8,
            fontWeight: FontWeight.w800,
            letterSpacing: fx.letterSpacing,
            color: c1,
            shadows: fx.glow > 0
                ? [
                    Shadow(
                        color: c1,
                        blurRadius: fx.glow *
                            .7 *
                            (fx.pulse ? (0.78 + 0.5 * sin(frac * pi)) : 1))
                  ]
                : null,
          ));
    }
    if (fx.pill) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: fx.sweep
            ? BoxDecoration(
                gradient: LinearGradient(colors: [
                  c1.withOpacity(.38), c1.withOpacity(.38),
                  c1.withOpacity(.16), c1.withOpacity(.16),
                ], stops: [0, frac, frac, 1]),
                borderRadius: BorderRadius.circular(20),
              )
            : BoxDecoration(
                color: c1.withOpacity(.28),
                borderRadius: BorderRadius.circular(20),
              ),
        child: content,
      );
    }
    return Transform.scale(scale: scale, child: content);
  }
}
