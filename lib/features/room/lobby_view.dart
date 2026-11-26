import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../game/case_model.dart';
import '../../network/client.dart';
import '../../widgets/brand.dart';
import '../../widgets/ui.dart';

class LobbyView extends StatelessWidget {
  const LobbyView({super.key, required this.onLeave});
  final VoidCallback onLeave;

  Future<void> _pickCase(BuildContext context) async {
    final cl = GameClient.i;
    final cases = await CaseLoader.loadAll();
    if (!context.mounted) return;
    var cat = 'random';
    var diff = 'standard';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setS) {
            Widget chip(String label, bool on, VoidCallback f) => ChoiceChip(
                  label: Text(label),
                  selected: on,
                  onSelected: (_) => f(),
                  selectedColor: C.red.withAlpha(60),
                  backgroundColor: C.panel2,
                  side: BorderSide(color: on ? C.red : C.line2),
                );
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                const SecTitle('پرونده جدید (ساخت خودکار)'),
                Text('هر بار یک پرونده کاملاً تازه با متهمان، دروغ‌ها، شاهدان و اثر انگشت ساخته می‌شود.',
                    style: ts(12, color: C.muted, h: 1.7)),
                const SizedBox(height: 12),
                AppBtn('ربات کارآگاه: یک پرونده تازه', icon: Icons.smart_toy_outlined, onTap: () {
                  cl.hostGenerate('random', 'auto');
                  Navigator.pop(sheet);
                }),
                const SizedBox(height: 6),
                Text('ربات خودش نوع و سختی پرونده را انتخاب می‌کند، آن را بررسی می‌کند و اگر مشکلی داشت پرونده دیگری می‌سازد.',
                    style: ts(11, color: C.muted, h: 1.7)),
                const SizedBox(height: 14),
                Text('یا خودتان انتخاب کنید', style: ts(12, color: C.dim)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  chip('تصادفی', cat == 'random', () => setS(() => cat = 'random')),
                  chip('قتل', cat == 'murder', () => setS(() => cat = 'murder')),
                  chip('سرقت', cat == 'theft', () => setS(() => cat = 'theft')),
                  chip('جاسوسی', cat == 'espionage', () => setS(() => cat = 'espionage')),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  chip('آسان', diff == 'easy', () => setS(() => diff = 'easy')),
                  chip('استاندارد', diff == 'standard', () => setS(() => diff = 'standard')),
                  chip('سخت', diff == 'hard', () => setS(() => diff = 'hard')),
                ]),
                const SizedBox(height: 12),
                AppBtn('ساخت پرونده جدید', icon: Icons.auto_awesome, onTap: () {
                  cl.hostGenerate(cat, diff);
                  Navigator.pop(sheet);
                }),
                const SecTitle('پرونده‌های آماده'),
                for (final c in cases)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CaseFileCard(
                      stamp: c.stamp,
                      title: c.title,
                      meta: [c.diffLabel, c.catLabel, '${fa(c.minPlayers)} تا ${fa(c.maxPlayers)} نفر'],
                      locked: Store.i.closed.containsKey(c.id),
                      lockText: Store.i.closed[c.id] == 'won' ? 'بسته‌شده · برد' : 'بسته‌شده · باخت',
                      solved: Store.i.closed[c.id] == 'won',
                      onTap: Store.i.closed.containsKey(c.id)
                          ? null
                          : () {
                              cl.hostSelect(c.id);
                              Navigator.pop(sheet);
                            },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cl = GameClient.i;
    final me = cl.me;
    final qr = jsonEncode({
      'ip': cl.ips.isEmpty ? '' : cl.ips[cl.ipIndex % cl.ips.length],
      'port': cl.port == 0 ? 8765 : (cl.hostServer?.port ?? cl.port),
      'code': cl.code,
      if (cl.hostServer != null && cl.hostServer!.relayBase.isNotEmpty) 'relay': cl.hostServer!.relayBase,
    });
    final canStart = cl.isHost && cl.caseId.isNotEmpty;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: Text(cl.roomName, style: ts(20, w: FontWeight.w800))),
        if (cl.isHost && (cl.hostServer?.relayOn ?? false)) ...[
          const Tag('آنلاین', color: C.green, icon: Icons.public),
          const SizedBox(width: 6),
        ],
        const Tag('لابی', color: C.blue, icon: Icons.groups_outlined),
      ]),
      const SizedBox(height: 12),
      if (cl.isHost)
        Panel(
          accent: C.blue,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: C.blue.withAlpha(70), blurRadius: 24)],
              ),
              child: QrImageView(data: qr, size: 170, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final ch in cl.code.split(''))
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 36,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [C.panel2, C.bg2],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: C.blue.withAlpha(150)),
                            boxShadow: [BoxShadow(color: C.blue.withAlpha(46), blurRadius: 12)],
                          ),
                          child: Text(ch, style: ts(24, w: FontWeight.w900, color: C.blue)),
                        ),
                    ]),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'کپی کد',
                icon: const Icon(Icons.copy, size: 20, color: C.muted),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: cl.code));
                  snack(context, 'کد اتاق کپی شد.');
                },
              ),
            ]),
            const SizedBox(height: 4),
            Text('بازیکنان فقط کافی است همین کد را در «ورود به اتاق» بزنند.', style: ts(11, color: C.muted)),
            if (cl.ips.isEmpty) ...[
              const SizedBox(height: 8),
              const SystemNotice('آدرس شبکه پیدا نشد. هات‌اسپات یا Wi-Fi را روشن کنید.',
                  icon: Icons.wifi_off, color: C.amber),
            ],
          ]),
        )
      else
        Panel(
          child: Row(children: [
            const Icon(Icons.vpn_key_outlined, color: C.muted),
            const SizedBox(width: 10),
            Text('کد اتاق', style: ts(13, color: C.muted)),
            const Spacer(),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(cl.code, style: ts(18, w: FontWeight.w800, ls: 4)),
            ),
          ]),
        ),
      const SecTitle('پرونده'),
      Panel(
        accent: cl.caseId.isEmpty ? null : C.red,
        child: Row(children: [
          Icon(Icons.folder_open, color: cl.caseId.isEmpty ? C.dim : C.red),
          const SizedBox(width: 12),
          Expanded(
            child: cl.caseId.isEmpty
                ? Text('هنوز پرونده‌ای انتخاب نشده است.', style: ts(13, color: C.muted))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cl.caseTitle, style: ts(16, w: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${fa(cl.minP)} تا ${fa(cl.maxP)} بازیکن', style: ts(12, color: C.muted)),
                  ]),
          ),
          if (cl.isHost)
            AppBtn(cl.caseId.isEmpty ? 'انتخاب' : 'تغییر',
                expand: false, height: 40, kind: BtnKind.ghost, onTap: () => _pickCase(context)),
        ]),
      ),
      SecTitle('بازیکنان ${fa(cl.players.length)} / ${fa(cl.cap)}'),
      for (var i = 0; i < cl.cap; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: i < cl.players.length ? _Slot(cl.players[i]) : const _EmptySlot(),
        ),
      const SizedBox(height: 12),
      if (cl.isHost)
        AppBtn('شروع پرونده', icon: Icons.play_arrow, onTap: canStart ? cl.hostStart : null)
      else
        AppBtn(
          me?['ready'] == true ? 'لغو آمادگی' : 'آماده‌ام',
          icon: me?['ready'] == true ? Icons.close : Icons.check,
          kind: me?['ready'] == true ? BtnKind.ghost : BtnKind.primary,
          onTap: () => cl.setReady(me?['ready'] != true),
        ),
      const SizedBox(height: 10),
      AppBtn('خروج از اتاق', icon: Icons.logout, kind: BtnKind.ghost, onTap: onLeave),
    ]);
  }
}

class _Slot extends StatelessWidget {
  const _Slot(this.p);
  final J p;

  @override
  Widget build(BuildContext context) {
    final up = p['up'] == true;
    final host = p['host'] == true;
    final ready = host || p['ready'] == true;
    return Panel(
      padding: const EdgeInsets.all(10),
      accent: ready && up ? C.green : null,
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 40, height: 48, child: CustomPaint(painter: AvatarPainter('${p['name']}${p['agent']}'))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p['name']}', style: ts(15, w: FontWeight.w700)),
            Text(ranks[((p['rank'] as num?) ?? 0).toInt().clamp(0, 3)].name, style: ts(11, color: C.muted)),
          ]),
        ),
        if (host) const Tag('میزبان', color: C.amber),
        const SizedBox(width: 6),
        up
            ? (ready
                ? const Tag('READY', color: C.green, icon: Icons.check)
                : const Tag('WAIT', color: C.muted, icon: Icons.hourglass_empty))
            : const Tag('قطع', color: C.red, icon: Icons.wifi_off),
      ]),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) => Container(
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.line, style: BorderStyle.solid),
          color: C.bg2.withAlpha(120),
        ),
        child: Text('در انتظار ورود بازیکن…', style: ts(12, color: C.dim)),
      );
}
