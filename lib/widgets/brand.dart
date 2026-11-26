import 'dart:math';

import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/support.dart';
import '../core/theme.dart';
import '../core/util.dart';
import 'effects.dart';
import 'ui.dart';

class LogoPainter extends CustomPainter {
  const LogoPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.shortestSide / 2 * 0.86;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.shortestSide * 0.018
      ..color = C.blue;
    canvas.drawCircle(
      c,
      r * 1.18,
      Paint()
        ..shader = RadialGradient(colors: [C.blue.withAlpha(70), Colors.transparent])
            .createShader(Rect.fromCircle(center: c, radius: r * 1.18)),
    );
    final tick = Paint()
      ..color = C.blue.withAlpha(150)
      ..strokeWidth = s.shortestSide * 0.006;
    for (var i = 0; i < 60; i++) {
      final a = i * pi / 30;
      final len = i % 5 == 0 ? 0.07 : 0.035;
      canvas.drawLine(
        Offset(c.dx + cos(a) * r * (0.97 - len), c.dy + sin(a) * r * (0.97 - len)),
        Offset(c.dx + cos(a) * r * 0.97, c.dy + sin(a) * r * 0.97),
        tick,
      );
    }
    canvas.drawCircle(c, r, stroke);
    canvas.drawCircle(c, r * 0.8, stroke..strokeWidth = s.shortestSide * 0.008..color = C.blue.withAlpha(120));
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.8)));
    final g = Paint()
      ..color = C.blue.withAlpha(40)
      ..strokeWidth = 0.8;
    final step = s.shortestSide / 12;
    for (double d = -r; d <= r; d += step) {
      canvas.drawLine(Offset(c.dx + d, c.dy - r), Offset(c.dx + d, c.dy + r), g);
      canvas.drawLine(Offset(c.dx - r, c.dy + d), Offset(c.dx + r, c.dy + d), g);
    }
    canvas.restore();
    final cross = Paint()
      ..color = C.red
      ..strokeWidth = s.shortestSide * 0.02;
    for (final a in [0.0, pi / 2, pi, 3 * pi / 2]) {
      canvas.drawLine(
        Offset(c.dx + cos(a) * r * 0.62, c.dy + sin(a) * r * 0.62),
        Offset(c.dx + cos(a) * r * 1.1, c.dy + sin(a) * r * 1.1),
        cross,
      );
    }
    final tp = TextPainter(
      text: TextSpan(
        text: '007',
        style: TextStyle(
          color: C.text,
          fontSize: s.shortestSide * 0.3,
          fontWeight: FontWeight.w900,
          letterSpacing: s.shortestSide * 0.02,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant LogoPainter old) => false;
}

class CaseLogo extends StatelessWidget {
  const CaseLogo({super.key, this.size = 120, this.showText = true});
  final double size;
  final bool showText;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: size, height: size, child: const CustomPaint(painter: LogoPainter())),
        if (showText) ...[
          SizedBox(height: size * 0.1),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text('CASE 007', style: ts(size * 0.22, w: FontWeight.w900, ls: size * 0.05)),
          ),
        ],
      ]);
}

class TopSecretStamp extends StatelessWidget {
  const TopSecretStamp({super.key, this.text = 'TOP SECRET', this.color = C.red, this.size = 20});
  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: -8 * pi / 180,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: size * 0.6, vertical: size * 0.2),
          decoration: BoxDecoration(
            border: Border.all(color: color.withAlpha(220), width: 3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: size * 0.4, vertical: size * 0.1),
            decoration: BoxDecoration(
              border: Border.all(color: color.withAlpha(160), width: 1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(text, style: ts(size, color: color.withAlpha(225), w: FontWeight.w900, ls: 3)),
            ),
          ),
        ),
      );
}

class AvatarPainter extends CustomPainter {
  const AvatarPainter(this.seed);
  final String seed;

  @override
  void paint(Canvas canvas, Size s) {
    final r = Random(seedOf(seed));
    final rect = Offset.zero & s;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF101826 + r.nextInt(0x1010)), const Color(0xFF0A0E16)],
        ).createShader(rect),
    );
    final w = s.width;
    final h = s.height;
    final glowRect = Rect.fromCircle(center: Offset(w / 2, h * 0.4), radius: w * 0.75);
    canvas.drawCircle(
      Offset(w / 2, h * 0.4),
      w * 0.75,
      Paint()
        ..shader = RadialGradient(colors: [C.blue.withAlpha(55), Colors.transparent]).createShader(glowRect),
    );
    final body = Paint()..color = Color.fromARGB(255, 40 + r.nextInt(30), 52 + r.nextInt(30), 70 + r.nextInt(40));
    canvas.drawOval(Rect.fromLTWH(w * 0.1, h * 0.66, w * 0.8, h * 0.6), body);
    final skin = Paint()..color = Color.fromARGB(255, 120 + r.nextInt(50), 100 + r.nextInt(40), 90 + r.nextInt(40));
    final head = Rect.fromCenter(center: Offset(w / 2, h * 0.42), width: w * 0.34, height: h * 0.4);
    canvas.drawOval(head, skin);
    canvas.drawArc(
      head,
      -pi * 0.15,
      pi * 0.6,
      false,
      Paint()
        ..color = C.blue.withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final hair = Paint()..color = Color.fromARGB(255, 18 + r.nextInt(40), 18 + r.nextInt(30), 24 + r.nextInt(30));
    switch (r.nextInt(3)) {
      case 0:
        canvas.drawArc(Rect.fromCenter(center: Offset(w / 2, h * 0.36), width: w * 0.38, height: h * 0.36), pi, pi, true, hair);
        break;
      case 1:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.32, h * 0.2, w * 0.36, h * 0.12), const Radius.circular(8)),
          hair,
        );
        break;
      default:
        canvas.drawArc(Rect.fromCenter(center: Offset(w / 2, h * 0.4), width: w * 0.44, height: h * 0.5), pi * 0.9, pi * 1.2, true, hair);
    }
    canvas.drawRect(
      Rect.fromLTWH(w * 0.34, h * 0.4, w * 0.32, h * 0.045),
      Paint()..color = C.blue.withAlpha(200),
    );
  }

  @override
  bool shouldRepaint(covariant AvatarPainter old) => old.seed != seed;
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter(this.seed);
  final String seed;

  @override
  void paint(Canvas canvas, Size s) {
    final r = Random(seedOf(seed));
    final p = Paint()..color = C.muted;
    double x = 0;
    while (x < s.width) {
      final w = 1 + r.nextInt(3).toDouble();
      canvas.drawRect(Rect.fromLTWH(x, 0, w, s.height), p);
      x += w + 1 + r.nextInt(3);
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter old) => false;
}

class RankBadge extends StatelessWidget {
  const RankBadge(this.idx, {super.key, this.size = 40});
  final int idx;
  final double size;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _RankPainter(idx)));
}

class _RankPainter extends CustomPainter {
  const _RankPainter(this.idx);
  final int idx;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.95, h * 0.18)
      ..lineTo(w * 0.95, h * 0.55)
      ..quadraticBezierTo(w * 0.9, h * 0.85, w * 0.5, h)
      ..quadraticBezierTo(w * 0.1, h * 0.85, w * 0.05, h * 0.55)
      ..lineTo(w * 0.05, h * 0.18)
      ..close();
    final col = [C.muted, C.blue, C.green, C.amber][idx.clamp(0, 3)];
    canvas.drawPath(path, Paint()..color = col.withAlpha(30));
    canvas.drawPath(path, Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 1.6);
    final p = Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeCap = StrokeCap.round;
    for (var i = 0; i <= idx; i++) {
      final y = h * 0.62 - i * h * 0.14;
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.28, y)
          ..lineTo(w * 0.5, y - h * 0.12)
          ..lineTo(w * 0.72, y),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RankPainter old) => old.idx != idx;
}

class AgentIdCard extends StatelessWidget {
  const AgentIdCard({
    super.key,
    required this.name,
    required this.code,
    required this.rankIdx,
    this.role,
  });
  final String name;
  final String code;
  final int rankIdx;
  final String? role;

  @override
  Widget build(BuildContext context) => Panel(
        accent: C.blue,
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 78, height: 96, child: CustomPaint(painter: AvatarPainter(name + code))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('کارت شناسایی مأمور', style: ts(11, color: C.muted)),
              const SizedBox(height: 4),
              Text(name, style: ts(18, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(role ?? ranks[rankIdx].name, style: ts(12, color: C.blue)),
              const SizedBox(height: 8),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text('ID-$code', style: ts(12, color: C.muted, ls: 2)),
              ),
              const SizedBox(height: 4),
              SizedBox(height: 14, width: double.infinity, child: CustomPaint(painter: _BarcodePainter(code))),
            ]),
          ),
          const SizedBox(width: 10),
          RankBadge(rankIdx, size: 42),
        ]),
      );
}

class SystemNotice extends StatelessWidget {
  const SystemNotice(this.text, {super.key, this.icon = Icons.shield_outlined, this.color = C.green});
  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) =>
            Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * -12), child: child)),
        child: Container(
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(60)),
            boxShadow: [BoxShadow(color: color.withAlpha(18), blurRadius: 16)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 3, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: 10),
                      Expanded(child: Text(text, style: ts(12, color: C.text, h: 1.5))),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

class CaseFileCard extends StatelessWidget {
  const CaseFileCard({
    super.key,
    required this.stamp,
    required this.title,
    required this.meta,
    this.locked = false,
    this.solved = false,
    this.onTap,
    this.lockText,
  });
  final String stamp;
  final String title;
  final List<String> meta;
  final bool locked;
  final bool solved;
  final VoidCallback? onTap;
  final String? lockText;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: locked ? 0.55 : 1,
        child: Panel(
          accent: solved ? C.green : (locked ? null : C.red),
          onTap: onTap,
          child: Row(children: [
            Container(
              width: 62,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: C.bg2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.line2),
              ),
              child: Column(children: [
                Icon(locked ? Icons.lock_outline : Icons.folder_open, color: locked ? C.dim : C.red, size: 22),
                const SizedBox(height: 6),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(stamp, style: ts(9, color: C.muted, w: FontWeight.w700, ls: 1)),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: ts(16, w: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final m in meta) Tag(m, color: C.muted),
                  if (solved) const Tag('حل‌شده', color: C.green, icon: Icons.check),
                  if (locked && lockText != null) Tag(lockText!, color: C.amber, icon: Icons.lock_outline),
                ]),
              ]),
            ),
          ]),
        ),
      );
}

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, this.progress, this.label = 'در حال بارگذاری…'});
  final Animation<double>? progress;
  final String label;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (!reduceMotion()) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Transform.scale(scale: 0.94 + 0.06 * _c.value, child: Opacity(opacity: 0.7 + 0.3 * _c.value, child: child)),
            child: const CaseLogo(size: 110),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 200,
            child: widget.progress == null
                ? const LinearProgressIndicator(minHeight: 3, color: C.red, backgroundColor: C.line)
                : AnimatedBuilder(
                    animation: widget.progress!,
                    builder: (context, _) => LinearProgressIndicator(
                      value: widget.progress!.value,
                      minHeight: 3,
                      color: C.red,
                      backgroundColor: C.line,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(widget.label, style: ts(12, color: C.muted)),
        ]),
      );
}

class SupportButton extends StatelessWidget {
  const SupportButton({super.key, this.expand = true});
  final bool expand;

  @override
  Widget build(BuildContext context) => AppBtn(
        'پشتیبانی',
        icon: Icons.support_agent,
        kind: BtnKind.ghost,
        expand: expand,
        onTap: () async {
          final ok = await openSupport();
          if (!ok && context.mounted) snack(context, 'تلگرام باز نشد. آیدی پشتیبانی: @$supportHandle');
        },
      );
}
