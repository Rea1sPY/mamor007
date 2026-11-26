import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/support.dart';
import '../core/theme.dart';
import '../widgets/brand.dart';
import '../widgets/effects.dart';
import '../widgets/hud.dart';
import '../widgets/ui.dart';
import 'login.dart';
import 'menu.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _boot = [
    'SECURE LINK ........... OK',
    'LOCAL NETWORK ......... READY',
    'CASE FILES ............ LOADED',
    'AGENT PROFILE ......... VERIFIED',
  ];

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        fxRoute(Store.i.codename.isEmpty ? const LoginScreen() : const MenuScreen()),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.bg,
        body: Backdrop(
          child: Stack(children: [
            GlitchEffect(child: LoadingScreen(progress: _c, label: 'برقراری ارتباط امن…')),
            Positioned(
              left: 28,
              right: 28,
              bottom: 96,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < _boot.length; i++)
                    Reveal(
                      index: 4 + i * 5,
                      dy: 6,
                      child: Text('> ${_boot[i]}', style: ts(10, color: C.green.withAlpha(200), w: FontWeight.w600, ls: 1)),
                    ),
                ]),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Column(children: [
                Text('نسخه ${appVersion.replaceAll('.', '٫')}', style: ts(11, color: C.dim)),
                const SizedBox(height: 4),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text('by $creditName', style: ts(12, color: C.muted, ls: 1.5)),
                ),
              ]),
            ),
          ]),
        ),
      );
}
