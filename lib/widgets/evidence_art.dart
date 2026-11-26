import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/util.dart';
import 'brand.dart';

class EvidenceArt extends StatefulWidget {
  const EvidenceArt({super.key, required this.scene, required this.caption, this.radius = 10, this.animated = true});
  final String scene;
  final String caption;
  final double radius;
  final bool animated;

  @override
  State<EvidenceArt> createState() => _EvidenceArtState();
}

class _EvidenceArtState extends State<EvidenceArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));

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
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _ArtPainter(widget.scene, widget.caption, widget.animated ? _c.value : 0),
            size: Size.infinite,
          ),
        ),
      );
}

class _ArtPainter extends CustomPainter {
  const _ArtPainter(this.scene, this.caption, this.t);
  final String scene;
  final String caption;
  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final r = Random(seedOf(scene + caption));
    final rect = Offset.zero & s;
    canvas.save();
    if ((t * 120).floor() % 41 == 0 && t > 0) canvas.translate(3, 0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1220), Color(0xFF1A2233), Color(0xFF0C0F16)],
        ).createShader(rect),
    );
    switch (scene) {
      case 'corridor':
        _corridor(canvas, w, h, r);
        break;
      case 'tower':
        _tower(canvas, w, h, r);
        break;
      case 'desk':
        _desk(canvas, w, h);
        break;
      default:
        _room(canvas, w, h, r);
    }
    canvas.restore();
    canvas.drawRect(rect, Paint()..color = const Color(0x1400FF9C));
    final cone = Path()
      ..moveTo(w * 0.46, 0)
      ..lineTo(w * 0.54, 0)
      ..lineTo(w * 0.95, h)
      ..lineTo(w * 0.05, h)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withAlpha(26), Colors.transparent],
        ).createShader(rect),
    );
    final by = (t % 1.0) * (h + 80) - 40;
    final band = Rect.fromLTWH(0, by - 28, w, 56);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white.withAlpha(18), Colors.transparent],
        ).createShader(band),
    );
    final gr = Random(seedOf(scene + caption) + (t * 40).floor());
    final grain = Paint()..color = Colors.white.withAlpha(14);
    for (var i = 0; i < 200; i++) {
      canvas.drawRect(Rect.fromLTWH(gr.nextDouble() * w, gr.nextDouble() * h, 1.4, 1.4), grain);
    }
    final line = Paint()..color = Colors.black.withAlpha(35);
    for (double y = 0; y < h; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, w, 1), line);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(radius: 0.9, colors: [Colors.transparent, Colors.black.withAlpha(170)])
            .createShader(rect),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: caption.isEmpty ? 'REC' : caption,
        style: const TextStyle(color: C.green, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: w - 20);
    tp.paint(canvas, Offset(10, h - tp.height - 8));
    final blink = sin(t * 2 * pi * 6) > 0 ? 1.0 : 0.2;
    canvas.drawCircle(Offset(w - 16, 16), 9, Paint()..color = C.red.withAlpha((60 * blink).round()));
    canvas.drawCircle(Offset(w - 16, 16), 4, Paint()..color = C.red.withAlpha((255 * blink).round()));
    final rec = TextPainter(
      text: const TextSpan(
        text: 'REC',
        style: TextStyle(color: C.red, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rec.paint(canvas, Offset(w - 32 - rec.width, 10));
    final sd = seedOf(scene + caption);
    String p2(int v) => v.toString().padLeft(2, '0');
    final sec = (sd + (t * 6).floor()) % 60;
    final stamp = TextPainter(
      text: TextSpan(
        text: 'CAM ${p2(sd % 8 + 1)}  ${p2(1 + sd % 4)}:${p2((sd ~/ 7) % 60)}:${p2(sec)}',
        style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    stamp.paint(canvas, const Offset(14, 12));
    final vf = Paint()
      ..color = Colors.white.withAlpha(120)
      ..strokeWidth = 1.4;
    const m = 8.0;
    const len = 14.0;
    void br(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * len, y), vf);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * len), vf);
    }
    br(m, m, 1, 1);
    br(w - m, m, -1, 1);
    br(m, h - m, 1, -1);
    br(w - m, h - m, -1, -1);
  }

  void _corridor(Canvas c, double w, double h, Random r) {
    final vp = Offset(w * 0.5, h * 0.46);
    final p = Paint()
      ..color = C.blue.withAlpha(70)
      ..strokeWidth = 1.2;
    for (final e in [Offset(0, 0), Offset(w, 0), Offset(0, h), Offset(w, h), Offset(0, h * 0.5), Offset(w, h * 0.5)]) {
      c.drawLine(e, vp, p);
    }
    for (var i = 1; i < 6; i++) {
      final t = i / 6;
      final rr = Rect.fromCenter(center: vp, width: w * (1 - t) * 1.1, height: h * (1 - t) * 1.1);
      c.drawRect(rr, p);
    }
    c.drawRect(Rect.fromCenter(center: vp, width: w * 0.08, height: h * 0.16), Paint()..color = C.amber.withAlpha(90));
    for (var i = 1; i < 6; i++) {
      final k = i / 6;
      final lc = Offset(vp.dx, vp.dy - h * 0.44 * (1 - k));
      final lw = w * 0.14 * (1 - k) + 6;
      c.drawCircle(lc, lw * 0.9, Paint()..color = C.blue.withAlpha(22));
      c.drawRect(Rect.fromCenter(center: lc, width: lw, height: 3), Paint()..color = Colors.white.withAlpha(170));
    }
    c.drawOval(
      Rect.fromCenter(center: Offset(w * 0.56, h * 0.7), width: w * 0.3, height: h * 0.07),
      Paint()..color = C.blue.withAlpha(34),
    );
    final body = Paint()..color = const Color(0xFF05070B);
    final fx = w * 0.56;
    c.drawCircle(Offset(fx, h * 0.42), h * 0.045, body);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(fx - h * 0.05, h * 0.465, h * 0.1, h * 0.2), const Radius.circular(8)),
      body,
    );
    c.drawRect(Rect.fromLTWH(fx - 2, h * 0.47, 4, h * 0.09), Paint()..color = C.blue);
    c.drawArc(
      Rect.fromCircle(center: Offset(fx, h * 0.42), radius: h * 0.045),
      -pi * 0.85,
      pi * 0.7,
      false,
      Paint()
        ..color = C.blue.withAlpha(170)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  void _tower(Canvas c, double w, double h, Random r) {
    final star = Paint()..color = Colors.white.withAlpha(120);
    for (var i = 0; i < 40; i++) {
      c.drawCircle(Offset(r.nextDouble() * w, r.nextDouble() * h * 0.5), 0.8, star);
    }
    c.drawCircle(Offset(w * 0.18, h * 0.14), h * 0.13, Paint()..color = Colors.white.withAlpha(16));
    c.drawCircle(Offset(w * 0.18, h * 0.14), h * 0.05, Paint()..color = const Color(0xDDE8EDF5));
    final dark = Paint()..color = const Color(0xFF04060A);
    for (var i = 0; i < 9; i++) {
      final bw = w * 0.09;
      final bh = h * (0.12 + r.nextDouble() * 0.2);
      c.drawRect(Rect.fromLTWH(i * bw * 1.1, h - bh, bw, bh), dark);
      for (var k = 0; k < 6; k++) {
        if (r.nextDouble() > 0.55) {
          c.drawRect(
            Rect.fromLTWH(i * bw * 1.1 + bw * 0.18 + (k % 2) * bw * 0.45, h - bh + bh * 0.12 + (k ~/ 2) * bh * 0.28, bw * 0.2, bh * 0.1),
            Paint()..color = C.amber.withAlpha(150),
          );
        }
      }
    }
    final tx = w * 0.62;
    c.drawRect(Rect.fromLTWH(tx - w * 0.02, h * 0.3, w * 0.04, h * 0.7), dark);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(tx - w * 0.09, h * 0.2, w * 0.18, h * 0.12), const Radius.circular(6)),
      dark,
    );
    c.drawRect(Rect.fromLTWH(tx - w * 0.07, h * 0.235, w * 0.14, h * 0.04), Paint()..color = C.amber.withAlpha(200));
    c.drawLine(Offset(tx, h * 0.2), Offset(tx, h * 0.1), Paint()..color = C.red..strokeWidth = 2);
    c.drawCircle(Offset(tx, h * 0.095), 3, Paint()..color = C.red);
  }

  void _desk(Canvas c, double w, double h) {
    c.drawRect(Rect.fromLTWH(0, h * 0.62, w, h * 0.38), Paint()..color = const Color(0xFF1C1710));
    c.drawRect(Rect.fromLTWH(0, h * 0.62, w, 3), Paint()..color = C.amber.withAlpha(90));
    final metal = Paint()..color = const Color(0xFF8D96A8);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.2, h * 0.28, w * 0.16, h * 0.36), const Radius.circular(10)),
      metal,
    );
    c.drawRect(Rect.fromLTWH(w * 0.2, h * 0.28, w * 0.16, h * 0.05), Paint()..color = C.red.withAlpha(200));
    final cup = Paint()..color = const Color(0xFFE8EDF5);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.55, h * 0.46, w * 0.12, h * 0.17), const Radius.circular(6)),
      cup,
    );
    c.drawArc(Rect.fromLTWH(w * 0.65, h * 0.5, w * 0.06, h * 0.08), -pi / 2, pi, false,
        Paint()..color = cup.color..style = PaintingStyle.stroke..strokeWidth = 3);
    c.drawOval(Rect.fromLTWH(w * 0.1, h * 0.7, w * 0.8, h * 0.06), Paint()..color = Colors.black.withAlpha(90));
    c.drawCircle(Offset(w * 0.5, h * 0.22), h * 0.16, Paint()..color = C.amber.withAlpha(26));
    for (final k in [0, 1]) {
      c.save();
      c.translate(w * (0.38 + k * 0.1), h * (0.74 + k * 0.03));
      c.rotate(k == 0 ? -0.18 : 0.12);
      c.drawRect(Rect.fromLTWH(0, 0, w * 0.2, h * 0.12), Paint()..color = const Color(0xDDD9D3C0));
      for (var l = 1; l < 5; l++) {
        c.drawRect(Rect.fromLTWH(w * 0.015, h * 0.022 * l, w * 0.15, 1.2), Paint()..color = const Color(0x553A4A66));
      }
      c.restore();
    }
    final steam = Paint()
      ..color = Colors.white.withAlpha(46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 3; k++) {
      final sx = w * (0.57 + k * 0.03);
      c.drawPath(
        Path()
          ..moveTo(sx, h * 0.44)
          ..cubicTo(sx - 6, h * 0.40, sx + 6, h * 0.36, sx, h * 0.32),
        steam,
      );
    }
    final lamp = Paint()
      ..color = const Color(0xFF2A2F3C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(w * 0.86, h * 0.64), Offset(w * 0.82, h * 0.4), lamp);
    c.drawLine(Offset(w * 0.82, h * 0.4), Offset(w * 0.72, h * 0.3), lamp);
    c.drawPath(
      Path()
        ..moveTo(w * 0.7, h * 0.27)
        ..lineTo(w * 0.78, h * 0.31)
        ..lineTo(w * 0.7, h * 0.36)
        ..close(),
      Paint()..color = const Color(0xFF3A4152),
    );
    c.drawPath(
      Path()
        ..moveTo(w * 0.72, h * 0.33)
        ..lineTo(w * 0.4, h * 0.66)
        ..lineTo(w * 0.8, h * 0.66)
        ..close(),
      Paint()..color = C.amber.withAlpha(20),
    );
  }

  void _room(Canvas c, double w, double h, Random r) {
    c.drawRect(Rect.fromLTWH(0, h * 0.7, w, h * 0.3), Paint()..color = const Color(0xFF10131B));
    final p = Paint()..color = C.blue.withAlpha(60);
    for (var i = 0; i < 4; i++) {
      final x = w * (0.1 + i * 0.22);
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, h * 0.3, w * 0.16, h * 0.4), const Radius.circular(4)),
        Paint()..color = const Color(0xFF0A0D14),
      );
      c.drawRect(Rect.fromLTWH(x + 6, h * 0.34, w * 0.16 - 12, h * 0.06), p);
      for (var k = 0; k < 3; k++) {
        c.drawCircle(Offset(x + 14 + k * 14, h * 0.5), 2.5, Paint()..color = [C.red, C.green, C.amber][(k + r.nextInt(3)) % 3]);
      }
      c.drawOval(Rect.fromLTWH(x - 4, h * 0.7, w * 0.24, h * 0.05), Paint()..color = C.blue.withAlpha(26));
    }
    c.drawRect(Rect.fromLTWH(0, h * 0.16, w, 3), Paint()..color = const Color(0xFF1A1F2B));
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.82, h * 0.06, w * 0.14, h * 0.07), const Radius.circular(3)),
      Paint()..color = C.green.withAlpha(200),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.82, h * 0.06, w * 0.14, h * 0.07), const Radius.circular(3)),
      Paint()..color = C.green.withAlpha(50)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) => old.scene != scene || old.caption != caption || old.t != t;
}

class _RuledPainter extends CustomPainter {
  const _RuledPainter(this.gap);
  final double gap;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = const Color(0x1A3A4A66);
    for (double y = gap; y < s.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(s.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _RuledPainter old) => false;
}

class PaperDoc extends StatelessWidget {
  const PaperDoc({super.key, required this.title, required this.content, this.note = false});
  final String title;
  final String content;
  final bool note;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1B1B22);
    final paper = note ? const Color(0xFFF1E2A0) : const Color(0xFFE9E3D1);
    return Transform.rotate(
      angle: note ? 0.012 : 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(Colors.white.withAlpha(46), paper),
              paper,
              Color.alphaBlend(Colors.black.withAlpha(34), paper),
            ],
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: CustomPaint(
          painter: const _RuledPainter(27),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: ts(17, color: ink, w: FontWeight.w800))),
              if (!note) const TopSecretStamp(text: 'CLASSIFIED', size: 11),
            ]),
            const Divider(color: Color(0x553A4A66), height: 22),
            Text(content, style: ts(14, color: ink, h: 1.95)),
          ]),
        ),
      ),
    );
  }
}
