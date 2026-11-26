import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../widgets/brand.dart';
import '../widgets/hud.dart';
import '../widgets/ui.dart';
import 'menu.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _ctl = TextEditingController(text: Store.i.codename);
  String? _err;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final n = _ctl.text.trim();
    if (n.length < 2 || n.length > 16) {
      setState(() => _err = 'نام رمز باید بین ۲ تا ۱۶ نویسه باشد.');
      return;
    }
    await Store.i.put('codename', n);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(fxRoute(const MenuScreen()));
  }

  @override
  Widget build(BuildContext context) => Stage(
        back: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Reveal(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CaseLogo(size: 96),
              const SizedBox(height: 28),
              Panel(
                accent: C.blue,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SecTitle('ورود به سامانه'),
                  Text('برای شروع، یک نام رمز انتخاب کنید. بازیکنان دیگر شما را با همین نام می‌بینند.',
                      style: ts(13, color: C.muted, h: 1.7)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _ctl,
                    maxLength: 16,
                    onChanged: (_) => setState(() => _err = null),
                    decoration: InputDecoration(labelText: 'نام رمز', errorText: _err, counterText: ''),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.badge_outlined, size: 16, color: C.muted),
                    const SizedBox(width: 6),
                    Text('کد مأمور: ', style: ts(12, color: C.muted)),
                    Text(fa(Store.i.agent), style: ts(12, color: C.blue, w: FontWeight.w700, ls: 2)),
                    const Spacer(),
                    Tag(ranks[Store.i.rank.idx].name, color: C.muted),
                  ]),
                  const SizedBox(height: 18),
                  AppBtn('ورود', icon: Icons.login, onTap: _go),
                ]),
              ),
            ])),
          ),
        ),
      );
}
