import 'dart:math';
import 'dart:ui' show PathOperation;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/util.dart';

/// Staggered fade + rise entrance. Give each sibling a growing [index].
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0, this.dy = 18});
  final Widget child;
  final int index;
  final double dy;

  @override
  Widget build(BuildContext context) {
    final delay = 70 * index;
    final total = 420 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(offset: Offset(0, (1 - t) * dy), child: c),
      ),
      child: child,
    );
  }
}

/// Thin HUD divider with a small Latin caption in the middle.
class HudDivider extends StatelessWidget {
  const HudDivider(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    Widget line(bool fadeLeft) => Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: fadeLeft
                    ? [Colors.transparent, C.line2]
                    : [C.line2, Colors.transparent],
              ),
            ),
          ),
        );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(children: [
        line(true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: ts(10, color: C.dim, w: FontWeight.w700, ls: 3)),
        ),
        line(false),
      ]),
    );
  }
}

/// Animated, glowing progress bar used for rank progress.
class RankBar extends StatelessWidget {
  const RankBar({super.key, required this.value, this.color = C.blue});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: v),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => Container(
        height: 8,
        decoration: BoxDecoration(
          color: C.line,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: C.line2.withAlpha(120), width: 0.5),
        ),
        child: FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: t,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [C.blueDeep, color]),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [BoxShadow(color: color.withAlpha(120), blurRadius: 10)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Square, bordered icon button used in headers.
class HudIconBtn extends StatelessWidget {
  const HudIconBtn({super.key, required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [C.panel2, C.panel],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.line2),
            ),
            child: Icon(icon, size: 20, color: C.muted),
          ),
        ),
      );
}

/// Big menu tile: glowing icon badge, faint watermark icon, press feedback.
class MenuTile extends StatefulWidget {
  const MenuTile({
    super.key,
    required this.art,
    required this.title,
    required this.sub,
    required this.color,
    required this.onTap,
    required this.no,
  });
  final GIcon art;
  final String title;
  final String sub;
  final Color color;
  final VoidCallback onTap;
  final String no;

  @override
  State<MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<MenuTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 140),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.withAlpha(_down ? 190 : 110)),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color.alphaBlend(c.withAlpha(40), C.panel2), C.panel],
            ),
            boxShadow: [
              const BoxShadow(color: Color(0x8C000000), blurRadius: 18, offset: Offset(0, 8)),
              BoxShadow(color: c.withAlpha(_down ? 60 : 26), blurRadius: 24),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(children: [
              Positioned(
                left: -16,
                bottom: -16,
                child: GameIcon(widget.art, size: 96, color: c.withAlpha(24)),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          color: c.withAlpha(30),
                          border: Border.all(color: c.withAlpha(150)),
                          boxShadow: [BoxShadow(color: c.withAlpha(70), blurRadius: 14)],
                        ),
                        child: Center(child: GameIcon(widget.art, size: 26, color: c)),
                      ),
                      const Spacer(),
                      Text(widget.no, style: ts(11, color: c.withAlpha(150), w: FontWeight.w800, ls: 1)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.title, style: ts(16, w: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(widget.sub, style: ts(11, color: C.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Hand-drawn icon set (replaces stock Material icons on key screens).
enum GIcon { room, join, cases, profile }

class GameIcon extends StatelessWidget {
  const GameIcon(this.kind, {super.key, this.size = 24, this.color = C.text});
  final GIcon kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GameIconPainter(kind, color)),
      );
}

class _GameIconPainter extends CustomPainter {
  const _GameIconPainter(this.kind, this.color);
  final GIcon kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size sz) {
    final s = sz.width;
    Offset o(double x, double y) => Offset(x * s, y * s);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = s * 0.075;
    final fill = Paint()..color = color;
    switch (kind) {
      case GIcon.room:
        final path = Path()
          ..moveTo(s * 0.5, s * 0.08)
          ..lineTo(s * 0.86, s * 0.22)
          ..lineTo(s * 0.86, s * 0.5)
          ..quadraticBezierTo(s * 0.86, s * 0.8, s * 0.5, s * 0.94)
          ..quadraticBezierTo(s * 0.14, s * 0.8, s * 0.14, s * 0.5)
          ..lineTo(s * 0.14, s * 0.22)
          ..close();
        canvas.drawPath(path, p);
        canvas.drawLine(o(0.5, 0.34), o(0.5, 0.66), p);
        canvas.drawLine(o(0.34, 0.5), o(0.66, 0.5), p);
        break;
      case GIcon.join:
        canvas.drawCircle(o(0.5, 0.5), s * 0.2, p);
        canvas.drawLine(o(0.5, 0.08), o(0.5, 0.26), p);
        canvas.drawLine(o(0.5, 0.74), o(0.5, 0.92), p);
        canvas.drawLine(o(0.08, 0.5), o(0.26, 0.5), p);
        canvas.drawLine(o(0.74, 0.5), o(0.92, 0.5), p);
        canvas.drawCircle(o(0.5, 0.5), s * 0.045, fill);
        break;
      case GIcon.cases:
        final f = Path()
          ..moveTo(s * 0.1, s * 0.26)
          ..lineTo(s * 0.4, s * 0.26)
          ..lineTo(s * 0.48, s * 0.36)
          ..lineTo(s * 0.9, s * 0.36)
          ..lineTo(s * 0.9, s * 0.84)
          ..lineTo(s * 0.1, s * 0.84)
          ..close();
        canvas.drawPath(f, p);
        canvas.drawCircle(o(0.56, 0.6), s * 0.11, p);
        canvas.drawLine(o(0.64, 0.68), o(0.74, 0.78), p);
        break;
      case GIcon.profile:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.2, s * 0.08, s * 0.6, s * 0.84), Radius.circular(s * 0.1)),
          p,
        );
        canvas.drawLine(o(0.4, 0.2), o(0.6, 0.2), p);
        canvas.drawCircle(o(0.5, 0.42), s * 0.1, p);
        canvas.drawArc(Rect.fromLTWH(s * 0.3, s * 0.58, s * 0.4, s * 0.3), 3.14159, 3.14159, false, p);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _GameIconPainter old) => old.kind != kind || old.color != color;
}

/// Square "keycap" choice used instead of stock ChoiceChips.
class KeyChoice extends StatelessWidget {
  const KeyChoice({super.key, required this.label, required this.selected, required this.onTap, this.color = C.red});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected ? [color.withAlpha(110), color.withAlpha(40)] : [C.panel2, C.bg2],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : C.line2),
            boxShadow: selected ? [BoxShadow(color: color.withAlpha(80), blurRadius: 14)] : null,
          ),
          child: Text(label, style: ts(16, w: FontWeight.w800, color: selected ? Colors.white : C.muted)),
        ),
      );
}

/// Game-phase stepper shown at the top of the room.
class PhaseBar extends StatelessWidget {
  const PhaseBar({super.key, required this.index, required this.labels});
  final int index;
  final List<String> labels;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Column(children: [
          Row(children: [
            Text(labels[index], style: ts(12, color: C.blue, w: FontWeight.w800)),
            const Spacer(),
            Text('${fa(index + 1)} / ${fa(labels.length)}', style: ts(11, color: C.muted)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < index ? C.blueDeep : (i == index ? C.blue : C.line),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: i == index ? [BoxShadow(color: C.blue.withAlpha(150), blurRadius: 8)] : null,
                  ),
                ),
              ),
          ]),
        ]),
      );
}


/// Animated ECG / stress monitor for interrogations. [stage] 0..3 raises heart rate.
class EcgMonitor extends StatefulWidget {
  const EcgMonitor({super.key, required this.stage});
  final int stage;

  @override
  State<EcgMonitor> createState() => _EcgMonitorState();
}

class _EcgMonitorState extends State<EcgMonitor> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.stage.clamp(0, 3);
    final color = const [C.green, C.amber, C.red, C.red][st];
    final bpm = 68 + st * 24;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: C.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(90)),
        boxShadow: [BoxShadow(color: color.withAlpha(24), blurRadius: 14)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(painter: _EcgPainter(color, st, _c.value)),
            ),
          ),
          Positioned(
            top: 6,
            left: 10,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text('HR $bpm', style: ts(10, color: color, w: FontWeight.w800, ls: 1)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  const _EcgPainter(this.color, this.stage, this.t);
  final Color color;
  final int stage;
  final double t;

  static double _beat(double u) {
    u = u - u.floorToDouble();
    if (u >= 0.28 && u < 0.31) return (u - 0.28) / 0.03 * 0.2;
    if (u >= 0.31 && u < 0.36) return 0.2 - (u - 0.31) / 0.05 * 1.4;
    if (u >= 0.36 && u < 0.41) return -1.2 + (u - 0.36) / 0.05 * 1.5;
    if (u >= 0.41 && u < 0.45) return 0.3 - (u - 0.41) / 0.04 * 0.3;
    if (u >= 0.60 && u < 0.75) return -0.25 * sin((u - 0.60) / 0.15 * pi);
    return 0;
  }

  @override
  void paint(Canvas canvas, Size s) {
    final grid = Paint()
      ..color = color.withAlpha(16)
      ..strokeWidth = 0.6;
    for (double x = 0; x < s.width; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x, s.height), grid);
    }
    for (double y = 0; y < s.height; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(s.width, y), grid);
    }
    final beats = 2.0 + stage;
    final mid = s.height * 0.62;
    final amp = s.height * 0.34;
    final path = Path();
    for (double x = 0; x <= s.width; x += 2) {
      final u = x / s.width * beats - t * beats;
      final jitter = stage >= 2 ? sin(x * 1.3 + t * 40) * 0.6 : 0.0;
      final y = mid + _beat(u) * amp + jitter;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withAlpha(60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _EcgPainter old) => old.t != t || old.stage != stage || old.color != color;
}

/// Three pulsing dots: "the suspect is answering".
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, this.color = C.blue});
  final Color color;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withAlpha((60 + 195 * max(0.0, sin((_c.value - i * 0.18) * 2 * pi))).round()),
              ),
            ),
        ]),
      );
}

/// Animated link lines between two compared fingerprints, with a similarity score.
class MatchBridge extends StatelessWidget {
  const MatchBridge({super.key, required this.verdict, required this.color, required this.seed});
  final String verdict;
  final Color color;
  final int seed;

  @override
  Widget build(BuildContext context) {
    int mode;
    int? score;
    switch (verdict) {
      case 'match':
        mode = 0;
        score = 92 + seed % 7;
        break;
      case 'maybe':
        mode = 1;
        score = 48 + seed % 16;
        break;
      case 'unusable':
        mode = 3;
        score = null;
        break;
      default:
        mode = 2;
        score = 5 + seed % 14;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 56,
        height: 84,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(painter: _BridgePainter(color, mode, t)),
        ),
      ),
      const SizedBox(height: 4),
      Text(score == null ? '—' : '${fa(score)}٪', style: ts(14, color: color, w: FontWeight.w900)),
    ]);
  }
}

class _BridgePainter extends CustomPainter {
  const _BridgePainter(this.color, this.mode, this.t);
  final Color color;
  final int mode;
  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final line = Paint()
      ..color = color.withAlpha(mode == 2 ? 120 : 220)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = color;
    for (var i = 0; i < 5; i++) {
      final y = s.height * (0.1 + i * 0.2);
      double y2;
      if (mode == 0) {
        y2 = y;
      } else if (mode == 1) {
        y2 = i < 2 ? y : s.height * (0.1 + ((i * 3) % 5) * 0.2);
      } else {
        y2 = s.height * (0.1 + ((i * 3 + 1) % 5) * 0.2);
      }
      if (mode == 3 && i.isOdd) continue;
      final path = Path()
        ..moveTo(0, y)
        ..cubicTo(s.width * 0.45, y, s.width * 0.55, y2, s.width, y2);
      final m = path.computeMetrics().first;
      canvas.drawPath(m.extractPath(0, m.length * t * (mode == 3 ? 0.4 : 1)), line);
      canvas.drawCircle(Offset(0, y), 2.4, dot);
      if (t > 0.95 && mode != 3) canvas.drawCircle(Offset(s.width, y2), 2.4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _BridgePainter old) => old.t != t || old.mode != mode || old.color != color;
}

/// Shared chat-bubble look. The small corner points at the speaker's side.
BoxDecoration bubbleDeco(bool mine) => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: mine ? [C.blue.withAlpha(46), C.blue.withAlpha(20)] : const [C.panel2, C.panel],
      ),
      borderRadius: BorderRadiusDirectional.only(
        topStart: const Radius.circular(14),
        topEnd: const Radius.circular(14),
        bottomStart: Radius.circular(mine ? 4 : 14),
        bottomEnd: Radius.circular(mine ? 14 : 4),
      ),
      border: Border.all(color: mine ? C.blue.withAlpha(120) : C.line2),
      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 3))],
    );

/// Live preview of a room code as individual slots (filled / next / empty).
class CodeSlots extends StatelessWidget {
  const CodeSlots({super.key, required this.text, this.length = 6});
  final String text;
  final int length;

  @override
  Widget build(BuildContext context) => Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 42,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [C.panel2, C.bg2],
                    ),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: i < text.length ? C.blue : (i == text.length ? C.amber : C.line2),
                      width: i == text.length ? 1.6 : 1,
                    ),
                    boxShadow: i < text.length ? [BoxShadow(color: C.blue.withAlpha(60), blurRadius: 12)] : null,
                  ),
                  child: Text(i < text.length ? text[i] : '', style: ts(24, w: FontWeight.w900, color: C.blue)),
                ),
            ]),
          ),
        ),
      );
}

/// QR scanner overlay: dimmed surround, glowing corner brackets and a sweeping laser.
class ScanOverlay extends StatefulWidget {
  const ScanOverlay({super.key, this.box = 240});
  final double box;

  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ScanOverlayPainter(widget.box, _c.value),
        ),
      );
}

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter(this.box, this.t);
  final double box;
  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromCenter(center: s.center(Offset.zero), width: box, height: box);
    final hole = RRect.fromRectAndRadius(r, const Radius.circular(18));
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & s), Path()..addRRect(hole)),
      Paint()..color = const Color(0x99000000),
    );
    final br = Paint()
      ..color = C.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = C.blue.withAlpha(110)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    const l = 30.0;
    for (final p in [br, glow]) {
      for (final sx in [-1.0, 1.0]) {
        for (final sy in [-1.0, 1.0]) {
          final cx = r.center.dx + sx * box / 2;
          final cy = r.center.dy + sy * box / 2;
          canvas.drawLine(Offset(cx, cy + sy * -l), Offset(cx, cy), p);
          canvas.drawLine(Offset(cx, cy), Offset(cx + sx * -l, cy), p);
        }
      }
    }
    final k = 0.5 - 0.5 * cos(t * 2 * pi);
    final y = r.top + 10 + (box - 20) * k;
    final band = Rect.fromLTWH(r.left + 8, y - 22, box - 16, 44);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, C.blue.withAlpha(70), Colors.transparent],
        ).createShader(band),
    );
    canvas.drawLine(
      Offset(r.left + 10, y),
      Offset(r.right - 10, y),
      Paint()
        ..color = C.blue
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter old) => old.t != t || old.box != box;
}
