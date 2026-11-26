import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';

bool reduceMotion() =>
    WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

class TypewriterText extends StatefulWidget {
  const TypewriterText(this.text, {super.key, this.style, this.msPerChar = 30, this.onDone});
  final String text;
  final TextStyle? style;
  final int msPerChar;
  final VoidCallback? onDone;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  Timer? _t;
  int _n = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(TypewriterText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _t?.cancel();
      _n = 0;
      _run();
    }
  }

  void _run() {
    if (reduceMotion()) {
      _n = widget.text.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone?.call());
      return;
    }
    _t = Timer.periodic(Duration(milliseconds: widget.msPerChar), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_n >= widget.text.length) {
        t.cancel();
        widget.onDone?.call();
        return;
      }
      setState(() => _n++);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(widget.text.substring(0, min(_n, widget.text.length)), style: widget.style);
}

class LightSweep extends StatefulWidget {
  const LightSweep({super.key, required this.child, this.radius = 10});
  final Widget child;
  final double radius;

  @override
  State<LightSweep> createState() => _LightSweepState();
}

class _LightSweepState extends State<LightSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3500));

  @override
  void initState() {
    super.initState();
    if (!reduceMotion()) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion()) return widget.child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, cons) => AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final w = cons.maxWidth;
                    final x = -0.4 * w + _c.value * 1.8 * w;
                    return Stack(children: [
                      Positioned(
                        left: x,
                        top: 0,
                        bottom: 0,
                        width: w * 0.22,
                        child: Transform(
                          transform: Matrix4.skewX(-0.4),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.white.withAlpha(0),
                                Colors.white.withAlpha(46),
                                Colors.white.withAlpha(0),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ]);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GlitchEffect extends StatefulWidget {
  const GlitchEffect({super.key, required this.child});
  final Widget child;

  @override
  State<GlitchEffect> createState() => _GlitchEffectState();
}

class _GlitchEffectState extends State<GlitchEffect> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void initState() {
    super.initState();
    if (Store.i.glitch && !reduceMotion()) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        if (!_c.isAnimating) return child!;
        final k = sin(_c.value * pi * 6) * (1 - _c.value) * 4;
        return Stack(
          children: [
            Transform.translate(
              offset: Offset(-k, 0),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(C.red.withAlpha(150), BlendMode.srcATop),
                child: child,
              ),
            ),
            Transform.translate(
              offset: Offset(k, 0),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(C.blue.withAlpha(150), BlendMode.srcATop),
                child: child,
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _Particle {
  _Particle(Random r, int layer)
      : x = r.nextDouble(),
        y = r.nextDouble(),
        v = layer + 1,
        ph = r.nextDouble() * 6.28,
        layer = layer;
  final double x;
  final double y;
  final int v;
  final double ph;
  final int layer;
}

class ParticleField extends StatefulWidget {
  const ParticleField({super.key, required this.count});
  final int count;

  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<ParticleField> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();
  late final List<_Particle> _ps = () {
    final r = Random(7);
    return List.generate(widget.count, (i) => _Particle(r, i % 3));
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: IgnorePointer(
          child: CustomPaint(painter: _ParticlePainter(_c, _ps), size: Size.infinite),
        ),
      );
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.c, this.ps) : super(repaint: c);
  final Animation<double> c;
  final List<_Particle> ps;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint();
    for (final q in ps) {
      final y = (q.y - c.value * q.v) % 1.0;
      final x = q.x + sin(c.value * 6.28 * q.v + q.ph) * 0.012;
      p.color = (q.layer == 2 ? C.blue : Colors.white).withAlpha(30 + q.layer * 28);
      canvas.drawCircle(Offset(x * s.width, y * s.height), 0.7 + q.layer * 0.6, p);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => false;
}

class ScanlineOverlay extends StatefulWidget {
  const ScanlineOverlay({super.key, this.animated = true});
  final bool animated;

  @override
  State<ScanlineOverlay> createState() => _ScanlineOverlayState();
}

class _ScanlineOverlayState extends State<ScanlineOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 7));

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
  Widget build(BuildContext context) => RepaintBoundary(
        child: IgnorePointer(
          child: CustomPaint(painter: _ScanPainter(_c), size: Size.infinite),
        ),
      );
}

class _ScanPainter extends CustomPainter {
  _ScanPainter(this.c) : super(repaint: c);
  final Animation<double> c;

  @override
  void paint(Canvas canvas, Size s) {
    final line = Paint()..color = Colors.white.withAlpha(7);
    for (double y = 0; y < s.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, s.width, 1), line);
    }
    final by = c.value * (s.height + 160) - 80;
    final band = Rect.fromLTWH(0, by, s.width, 80);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.blue.withAlpha(0), C.blue.withAlpha(14), C.blue.withAlpha(0)],
        ).createShader(band),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanPainter old) => false;
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = C.line.withAlpha(110)
      ..strokeWidth = 0.6;
    for (double x = 0; x < s.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, s.height), p);
    }
    for (double y = 0; y < s.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(s.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => false;
}

class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        final off = reduceMotion();
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: C.bg),
            const RepaintBoundary(child: CustomPaint(painter: _GridPainter())),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.95, -0.95),
                    radius: 0.95,
                    colors: [C.blue.withAlpha(36), Colors.transparent],
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.95, 1.0),
                    radius: 0.9,
                    colors: [C.red.withAlpha(30), Colors.transparent],
                  ),
                ),
              ),
            ),
            if (s.particles && !off) ParticleField(key: ValueKey(s.particleCount), count: s.particleCount),
            if (s.scanline) ScanlineOverlay(animated: !off && !s.saver),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.1,
                    colors: [Colors.transparent, Colors.black.withAlpha(150)],
                    stops: const [0.55, 1],
                  ),
                ),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}
