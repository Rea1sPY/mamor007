import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Draws a procedural fingerprint. Same pattern+seed always gives the same print.
class FingerprintArt extends StatefulWidget {
  const FingerprintArt({
    super.key,
    required this.pattern,
    required this.seed,
    this.quality = 'clear',
    this.size = 120,
    this.color = C.blue,
    this.animated = true,
  });

  final String pattern;
  final int seed;
  final String quality;
  final double size;
  final Color color;
  final bool animated;

  @override
  State<FingerprintArt> createState() => _FingerprintArtState();
}

class _FingerprintArtState extends State<FingerprintArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    if (widget.animated) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: widget.size,
        height: widget.size * 1.15,
        decoration: BoxDecoration(
          color: C.bg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: widget.color.withAlpha(90)),
          boxShadow: [BoxShadow(color: widget.color.withAlpha(28), blurRadius: 18)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: _FpPainter(widget.pattern, widget.seed, widget.quality, widget.color, widget.animated ? _c.value : -1),
            ),
          ),
        ),
      );
}

class _FpPainter extends CustomPainter {
  const _FpPainter(this.pattern, this.seed, this.quality, this.color, this.t);

  final String pattern;
  final int seed;
  final String quality;
  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final r = Random(seed);
    final w = s.width;
    final h = s.height;
    final paint = Paint()
      ..color = color.withAlpha(quality == 'smudged' ? 110 : 225)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(1.0, w / 60);
    final full = Offset.zero & s;
    canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.1),
          radius: 0.85,
          colors: [color.withAlpha(46), Colors.transparent],
        ).createShader(full),
    );
    final grid = Paint()
      ..color = color.withAlpha(18)
      ..strokeWidth = 0.6;
    for (var i = 1; i < 8; i++) {
      canvas.drawLine(Offset(w * i / 8, 0), Offset(w * i / 8, h), grid);
      canvas.drawLine(Offset(0, h * i / 8), Offset(w, h * i / 8), grid);
    }
    final brk = Paint()
      ..color = color.withAlpha(200)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final bl = w * 0.12;
    for (final cx in [6.0, w - 6.0]) {
      for (final cy in [6.0, h - 6.0]) {
        final dx = cx < w / 2 ? 1.0 : -1.0;
        final dy = cy < h / 2 ? 1.0 : -1.0;
        canvas.drawLine(Offset(cx, cy), Offset(cx + dx * bl, cy), brk);
        canvas.drawLine(Offset(cx, cy), Offset(cx, cy + dy * bl), brk);
      }
    }
    canvas.save();
    if (quality == 'partial') {
      final cut = Path()
        ..addOval(Rect.fromLTWH(w * (0.02 + r.nextDouble() * 0.2), h * (0.05 + r.nextDouble() * 0.15), w * 0.72, h * 0.7));
      canvas.clipPath(cut);
    }
    const rings = 13;
    if (pattern == 'whorl') {
      final path = Path();
      const turns = 6.5;
      var first = true;
      for (double a = 0; a < 2 * pi * turns; a += 0.1) {
        final k = a / (2 * pi * turns);
        final x = w / 2 + cos(a) * k * w * 0.46 + (r.nextDouble() - 0.5) * 0.7;
        final y = h * 0.52 + sin(a) * k * h * 0.42 + (r.nextDouble() - 0.5) * 0.7;
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    } else if (pattern == 'arch') {
      for (var i = 0; i < rings; i++) {
        final t = i / rings;
        final rect = Rect.fromLTWH(w * 0.06, h * (0.2 + t * 0.75), w * 0.88, h * 0.55 * (1 - t * 0.25));
        canvas.drawArc(rect, pi, pi, false, paint);
      }
    } else {
      for (var i = 1; i <= rings; i++) {
        final t = i / rings;
        final rect = Rect.fromCenter(center: Offset(w / 2, h * 0.62), width: w * 0.9 * t, height: h * 0.8 * t);
        canvas.drawArc(rect, -pi * 0.97, pi * 1.94, false, paint);
      }
    }
    final dot = Paint()..color = C.amber.withAlpha(170);
    for (var i = 0; i < 9; i++) {
      canvas.drawCircle(Offset(w * (0.2 + r.nextDouble() * 0.6), h * (0.2 + r.nextDouble() * 0.6)), max(1.4, w / 55) * (1 + 0.35 * sin(max(t, 0) * 4 * pi)), dot);
    }
    if (quality == 'smudged') {
      final blob = Paint()..color = C.bg2.withAlpha(185);
      for (var i = 0; i < 7; i++) {
        canvas.drawCircle(Offset(w * r.nextDouble(), h * r.nextDouble()), w * (0.08 + r.nextDouble() * 0.16), blob);
      }
    }
    canvas.restore();
    if (t >= 0) {
      final y = t * h;
      final band = Rect.fromLTWH(0, y - 20, w, 40);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, color.withAlpha(90), Colors.transparent],
          ).createShader(band),
      );
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        Paint()
          ..color = color.withAlpha(230)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FpPainter old) =>
      old.pattern != pattern || old.seed != seed || old.quality != quality || old.t != t;
}
