import 'package:flutter/material.dart';

import '../core/relay_config.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../game/case_model.dart';
import '../network/client.dart';
import '../network/host.dart';
import '../widgets/brand.dart';
import '../widgets/hud.dart';
import '../widgets/ui.dart';
import 'room/room_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _name = TextEditingController(text: 'اتاق ${Store.i.codename}');
  int _max = 4;
  bool _online = false;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final n = _name.text.trim();
    if (n.isEmpty || n.length > 24) {
      setState(() => _err = 'نام اتاق باید بین ۱ تا ۲۴ نویسه باشد.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final cases = await CaseLoader.loadAll();
    final host = GameHost(
      code: newRoomCode(),
      roomName: n,
      maxPlayers: _max,
      hostPid: Store.i.pid,
      cases: {for (final c in cases) c.id: c},
    );
    try {
      await host.start();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = 'راه‌اندازی سرور محلی ممکن نشد. پورت‌ها اشغال هستند.';
        });
      }
      return;
    }
    if (_online) {
      final relayErr = await host.startRelay(effectiveRelay());
      if (relayErr != null) {
        await host.close();
        if (mounted) {
          setState(() {
            _busy = false;
            _err = relayErr;
          });
        }
        return;
      }
    }
    final cl = GameClient.i;
    final err = await cl.join(ip: '127.0.0.1', port: host.port, code: host.code, host: true);
    if (err != null) {
      await host.close();
      if (mounted) {
        setState(() {
          _busy = false;
          _err = err;
        });
      }
      return;
    }
    cl.hostServer = host;
    cl.ips = await localAddresses();
    cl.ipIndex = 0;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(fxRoute(const RoomScreen()));
  }

  @override
  Widget build(BuildContext context) => Stage(
        title: 'ساخت اتاق',
        child: _busy
            ? const LoadingScreen(label: 'در حال راه‌اندازی اتاق…')
            : ListView(padding: const EdgeInsets.all(16), children: [
                const SystemNotice('پس از ساخت اتاق، کد و QR نمایش داده می‌شود. بقیه بازیکنان باید به همان Wi-Fi یا هات‌اسپات شما وصل باشند.',
                    icon: Icons.wifi_tethering, color: C.blue),
                const SizedBox(height: 16),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SecTitle('مشخصات اتاق'),
                    TextField(
                      controller: _name,
                      maxLength: 24,
                      decoration: InputDecoration(labelText: 'نام اتاق', errorText: _err, counterText: ''),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: C.blue,
                      title: Text('اتاق آنلاین', style: ts(14, w: FontWeight.w600)),
                      subtitle: Text(
                        effectiveRelay().isEmpty
                            ? 'برای فعال‌شدن، آدرس سرور آنلاین را در تنظیمات وارد کنید.'
                            : 'دوستان از هر جای دنیا فقط با کد اتاق وارد می‌شوند.',
                        style: ts(11, color: C.muted),
                      ),
                      value: _online && effectiveRelay().isNotEmpty,
                      onChanged: effectiveRelay().isEmpty ? null : (v) => setState(() => _online = v),
                    ),
                    const SizedBox(height: 8),
                    Text('حداکثر تعداد بازیکن', style: ts(13, color: C.muted)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      for (var n = 1; n <= 6; n++)
                        KeyChoice(label: fa(n), selected: _max == n, onTap: () => setState(() => _max = n)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 18),
                AppBtn('ساخت اتاق', icon: Icons.add_moderator_outlined, onTap: _create),
              ]),
      );
}
