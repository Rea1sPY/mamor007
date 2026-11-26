import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/relay_config.dart';
import '../core/theme.dart';
import '../network/client.dart';
import '../widgets/brand.dart';
import '../widgets/hud.dart';
import '../widgets/ui.dart';
import 'room/room_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  bool _online = false;
  String? _err;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final v = await Navigator.of(context).push<String>(fxRoute(const _ScanScreen()));
    if (v == null) return;
    try {
      final o = jsonDecode(v) as Map<String, dynamic>;
      final code = '${o['code']}'.toUpperCase();
      if (code.length != 6) throw const FormatException('code');
      _code.text = code;
      final ip = '${o['ip'] ?? ''}';
      final port = (o['port'] as num?)?.toInt() ?? 8765;
      final relay = normalizeRelayUrl('${o['relay'] ?? ''}') ?? '';
      await _join(hintIp: ip, hintPort: port, hintRelay: relay);
    } catch (_) {
      setState(() => _err = 'این QR مربوط به CASE 007 نیست.');
    }
  }

  Future<void> _join({String hintIp = '', int hintPort = 8765, String hintRelay = ''}) async {
    final code = _code.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _err = 'کد اتاق ۶ نویسه است.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    String? err;
    if (hintRelay.isNotEmpty || _online) {
      err = await GameClient.i.joinOnline(code, base: hintRelay.isEmpty ? null : hintRelay);
    } else {
      if (hintIp.isNotEmpty) {
        err = await GameClient.i.join(ip: hintIp, port: hintPort, code: code);
      }
      if (hintIp.isEmpty || err != null) {
        err = await GameClient.i.joinByCode(code);
      }
    }
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _err = err;
      });
      return;
    }
    Navigator.of(context).pushReplacement(fxRoute(const RoomScreen()));
  }

  @override
  Widget build(BuildContext context) => Stage(
        title: 'ورود به اتاق',
        child: _busy
            ? LoadingScreen(label: _online ? 'در حال اتصال به اتاق آنلاین…' : 'در حال جست‌وجوی میزبان در شبکه…')
            : ListView(padding: const EdgeInsets.all(16), children: [
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('شبکه محلی'), icon: Icon(Icons.wifi)),
                    ButtonSegment(value: true, label: Text('آنلاین'), icon: Icon(Icons.public)),
                  ],
                  selected: {_online},
                  onSelectionChanged: (v) => setState(() {
                    _online = v.first;
                    _err = null;
                  }),
                ),
                const SizedBox(height: 12),
                SystemNotice(
                  _online
                      ? 'فقط کد اتاق را بزنید؛ از طریق اینترنت به میزبان وصل می‌شوید و لازم نیست در یک شبکه باشید.'
                      : 'فقط کد اتاق را بزنید؛ میزبان خودکار در شبکه پیدا می‌شود و نیازی به نوشتن IP نیست.',
                  icon: _online ? Icons.public : Icons.wifi_find,
                  color: C.blue,
                ),
                const SizedBox(height: 16),
                Panel(
                  child: Column(children: [
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _code,
                      builder: (context, v, _) => CodeSlots(text: v.text.toUpperCase(), length: 6),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _code,
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      onSubmitted: (_) => _join(),
                      style: ts(24, w: FontWeight.w800, ls: 8),
                      decoration: const InputDecoration(labelText: 'کد اتاق', counterText: ''),
                    ),
                    if (_err != null) ...[
                      const SizedBox(height: 12),
                      SystemNotice(_err!, icon: Icons.error_outline, color: C.red),
                    ],
                  ]),
                ),
                const SizedBox(height: 16),
                AppBtn('ورود', icon: Icons.login, onTap: _join),
                const SizedBox(height: 12),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('یا', style: ts(12, color: C.muted))),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 12),
                AppBtn('اسکن QR میزبان', icon: Icons.qr_code_scanner, kind: BtnKind.ghost, onTap: _scan),
              ]),
      );
}

class _ScanScreen extends StatefulWidget {
  const _ScanScreen();

  @override
  State<_ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<_ScanScreen> with WidgetsBindingObserver {
  final MobileScannerController _ctl = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;
  String? _problem; // denied, perm, or an error text

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _begin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _problem != null) _begin();
  }

  Future<void> _begin() async {
    var st = await Permission.camera.status;
    if (!st.isGranted) st = await Permission.camera.request();
    if (!mounted) return;
    if (!st.isGranted) {
      setState(() => _problem = st.isPermanentlyDenied ? 'perm' : 'denied');
      return;
    }
    try {
      await _ctl.start();
      if (mounted) setState(() => _problem = null);
    } catch (e) {
      if (mounted) setState(() => _problem = 'خطای دوربین: $e');
    }
  }

  String get _message {
    switch (_problem) {
      case 'denied':
        return 'برای اسکن QR اجازهٔ دوربین لازم است. دوباره تلاش کنید و «اجازه» را بزنید، یا کد را دستی وارد کنید.';
      case 'perm':
        return 'اجازهٔ دوربین برای این برنامه بسته شده است. از تنظیمات گوشی اجازه را فعال کنید و برگردید.';
      default:
        return '${_problem ?? ''}\nاگر مشکل ادامه داشت، کد اتاق را دستی وارد کنید.';
    }
  }

  @override
  Widget build(BuildContext context) => Stage(
        title: 'اسکن QR',
        child: Stack(children: [
          MobileScanner(
            controller: _ctl,
            onDetect: (cap) {
              if (_done) return;
              for (final b in cap.barcodes) {
                final v = b.rawValue;
                if (v != null) {
                  _done = true;
                  Navigator.of(context).pop(v);
                  return;
                }
              }
            },
            errorBuilder: (context, error, child) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('خطای دوربین (${error.errorCode.name}). دوباره تلاش کنید یا کد را دستی وارد کنید.',
                    textAlign: TextAlign.center, style: ts(14, color: C.muted, h: 1.8)),
              ),
            ),
          ),
          if (_problem == null)
            const Positioned.fill(child: IgnorePointer(child: ScanOverlay()))
          else
            Container(
              color: C.bg.withAlpha(235),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.no_photography_outlined, color: C.amber, size: 44),
                  const SizedBox(height: 14),
                  Text(_message, textAlign: TextAlign.center, style: ts(14, color: C.muted, h: 1.9)),
                  const SizedBox(height: 18),
                  if (_problem == 'perm')
                    AppBtn('باز کردن تنظیمات', icon: Icons.settings, onTap: openAppSettings)
                  else
                    AppBtn('تلاش دوباره', icon: Icons.refresh, onTap: _begin),
                ]),
              ),
            ),
        ]),
      );
}
