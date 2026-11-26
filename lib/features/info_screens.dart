import 'package:flutter/material.dart';

import '../core/badges.dart';
import '../core/relay_config.dart';
import '../core/store.dart';
import '../core/support.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../game/case_model.dart';
import '../widgets/brand.dart';
import '../widgets/hud.dart';
import '../widgets/ui.dart';
import 'guide_screen.dart';
import 'login.dart';

class CasesScreen extends StatelessWidget {
  const CasesScreen({super.key});

  @override
  Widget build(BuildContext context) => Stage(
        title: 'پرونده‌ها',
        child: FutureBuilder<List<CaseData>>(
          future: CaseLoader.loadAll(),
          builder: (context, snap) {
            if (!snap.hasData) return const LoadingScreen(label: 'بارگذاری پرونده‌ها…');
            final s = Store.i;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final c in snap.data!)
                  Reveal(index: snap.data!.indexOf(c), child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CaseFileCard(
                      stamp: c.stamp,
                      title: c.title,
                      meta: [c.diffLabel, c.catLabel, '${fa(c.minPlayers)} تا ${fa(c.maxPlayers)} نفر'],
                      locked: s.closed.containsKey(c.id),
                      lockText: s.closed[c.id] == 'won' ? 'بسته‌شده · برد' : 'بسته‌شده · باخت',
                      solved: s.closed[c.id] == 'won',
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (d) => AlertDialog(
                          backgroundColor: C.panel,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: C.line2),
                          ),
                          title: Text(c.title, style: ts(17, w: FontWeight.w700)),
                          content: Text(c.brief, style: ts(13, color: C.muted, h: 1.8)),
                          actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('بستن'))],
                        ),
                      ),
                    ),
                  )),
              ],
            );
          },
        ),
      );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => Stage(
        title: 'پروفایل',
        child: ListenableBuilder(
          listenable: Store.i,
          builder: (context, _) {
            final s = Store.i;
            Widget stat(String l, num v, IconData i, Color c) => Expanded(
                  child: Panel(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    child: Column(children: [
                      Icon(i, color: c, size: 20),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: v.toDouble()),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, _) => Text(fa(t.round()), style: ts(20, w: FontWeight.w800, color: c)),
                      ),
                      const SizedBox(height: 2),
                      Text(l, style: ts(11, color: C.muted)),
                    ]),
                  ),
                );
            return ListView(padding: const EdgeInsets.all(16), children: [
              AgentIdCard(name: s.codename, code: s.agent, rankIdx: s.rank.idx),
              const SizedBox(height: 12),
              Row(children: [
                stat('باخت', s.lost, Icons.close, C.red),
                const SizedBox(width: 8),
                stat('برد', s.wins, Icons.emoji_events_outlined, C.amber),
                const SizedBox(width: 8),
                stat('بازی', s.played, Icons.sports_esports_outlined, C.blue),
                const SizedBox(width: 8),
                stat('حل‌شده', s.solved.length, Icons.task_alt, C.green),
              ]),
              const SizedBox(height: 12),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.percent, color: C.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('نرخ حل پرونده', style: ts(14, w: FontWeight.w700))),
                    Text('${fa(s.winRatePct)}٪', style: ts(16, w: FontWeight.w800, color: C.green)),
                  ]),
                  const SizedBox(height: 10),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: s.winRatePct / 100),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: t, minHeight: 6, color: C.green, backgroundColor: C.line),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.played == 0
                        ? 'هنوز پرونده‌ای بسته نشده است.'
                        : '${fa(s.wins)} پرونده حل‌شده از ${fa(s.played)} پرونده بسته‌شده',
                    style: ts(11, color: C.muted),
                  ),
                ]),
              ),
              const SecTitle('نشان‌ها'),
              LayoutBuilder(builder: (context, box) {
                final w = (box.maxWidth - 8) / 2;
                final list = badgesFor(
                  wins: s.wins,
                  played: s.played,
                  lost: s.lost,
                  bestStreak: s.bestStreak,
                  rankIdx: s.rank.idx,
                  winRatePct: s.winRatePct,
                );
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final b in list)
                    SizedBox(
                      width: w,
                      child: Opacity(
                        opacity: b.earned ? 1 : 0.45,
                        child: Panel(
                          accent: b.earned ? C.amber : null,
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(b.earned ? b.icon : Icons.lock_outline, color: b.earned ? C.amber : C.dim, size: 22),
                            const SizedBox(height: 8),
                            Text(b.title, style: ts(13, w: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(b.desc, style: ts(10, color: C.muted, h: 1.6)),
                          ]),
                        ),
                      ),
                    ),
                ]);
              }),
              const SecTitle('رتبه‌ها'),
              for (final r in ranks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Opacity(opacity: r.idx > s.rank.idx ? 0.5 : 1, child: Panel(
                    accent: s.rank.idx == r.idx ? C.green : null,
                    child: Row(children: [
                      RankBadge(r.idx, size: 34),
                      const SizedBox(width: 12),
                      Expanded(child: Text(r.name, style: ts(15, w: FontWeight.w700))),
                      Text('${fa(r.min)}+', style: ts(12, color: C.muted)),
                      if (r.idx > s.rank.idx) ...[const SizedBox(width: 8), const Icon(Icons.lock_outline, size: 16, color: C.dim)],
                    ]),
                  )),
                ),
            ]);
          },
        ),
      );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Stage(
        title: 'تنظیمات',
        child: ListenableBuilder(
          listenable: Store.i,
          builder: (context, _) {
            final s = Store.i;
            Widget sw(String t, String sub, bool v, String key) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: C.blue,
                  title: Text(t, style: ts(14, w: FontWeight.w600)),
                  subtitle: Text(sub, style: ts(11, color: C.muted)),
                  value: v,
                  onChanged: (x) => s.put(key, x),
                );
            return ListView(padding: const EdgeInsets.all(16), children: [
              Panel(
                child: Column(children: [
                  const SecTitle('جلوه‌های بصری'),
                  sw('ذرات شناور', 'ذرات پس‌زمینه', s.particles, 'particles'),
                  sw('خطوط اسکن', 'اسکن‌لاین روی صفحه', s.scanline, 'scanline'),
                  sw('افکت گلیچ', 'لرزش لحظه‌ای عنوان‌ها', s.glitch, 'glitch'),
                  sw('حالت کم‌مصرف', 'کاهش انیمیشن و ذرات', s.saver, 'saver'),
                ]),
              ),
              const SizedBox(height: 12),
              Panel(
                child: Column(children: [
                  const SecTitle('بازخورد لمسی و صدا'),
                  sw('لرزش', 'لرزش ملایم هنگام لمس، تغییر مرحله و اعلام نتیجه', s.haptics, 'haptics'),
                  sw('جلوه‌های صوتی', 'صدای دکمه‌ها، پیام‌ها، آزمایشگاه و اعلام نتیجه', s.sound, 'sound'),
                ]),
              ),
              const SizedBox(height: 12),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SecTitle('کیفیت و نمایش'),
                  Text('کیفیت گرافیکی', style: ts(13, color: C.muted)),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('کم')),
                      ButtonSegment(value: 1, label: Text('متوسط')),
                      ButtonSegment(value: 2, label: Text('زیاد')),
                    ],
                    selected: {s.quality},
                    onSelectionChanged: (v) => s.put('quality', v.first),
                  ),
                  const SizedBox(height: 8),
                  sw('اندازه بزرگ متن', 'افزایش اندازه فونت', s.largeFont, 'largeFont'),
                ]),
              ),
              const SizedBox(height: 12),
              const _RelayPanel(),
              const SizedBox(height: 12),
              AppBtn('راهنمای بازی', icon: Icons.menu_book_outlined, kind: BtnKind.ghost,
                  onTap: () => Navigator.of(context).push(fxRoute(const GuideScreen()))),
              const SizedBox(height: 10),
              const SupportButton(),
              const SizedBox(height: 10),
              AppBtn('پاک‌کردن همه داده‌ها', icon: Icons.delete_outline, kind: BtnKind.danger, onTap: () async {
                final ok = await confirm(context, 'پاک‌کردن داده‌ها',
                    'پروفایل، امتیازها و تنظیمات این گوشی حذف می‌شود. ادامه می‌دهید؟');
                if (!ok) return;
                await Store.i.wipe();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(fxRoute(const LoginScreen()), (r) => false);
                }
              }),
            ]);
          },
        ),
      );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Stage(
        title: 'درباره',
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const Center(child: CaseLogo(size: 110)),
          const SizedBox(height: 24),
          Panel(
            child: Column(children: [
              Text('پرونده ۰۰۷', style: ts(20, w: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('بازی کارآگاهی چندنفره آفلاین', style: ts(13, color: C.muted)),
              const SizedBox(height: 14),
              Text('نسخه ${fa(appVersion)}', style: ts(12, color: C.dim)),
              const SizedBox(height: 14),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text('Created by $creditName', style: ts(15, color: C.blue, w: FontWeight.w700, ls: 1)),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          const SupportButton(),
          const SizedBox(height: 10),
          AppBtn('مجوزها', icon: Icons.description_outlined, kind: BtnKind.ghost, onTap: () => showLicensePage(
                context: context,
                applicationName: 'CASE 007',
                applicationVersion: appVersion,
              )),
        ]),
      );
}

/// Address of the online relay (see relay/README.md). Empty uses the built-in one.
class _RelayPanel extends StatefulWidget {
  const _RelayPanel();

  @override
  State<_RelayPanel> createState() => _RelayPanelState();
}

class _RelayPanelState extends State<_RelayPanel> {
  late final TextEditingController _c = TextEditingController(text: Store.i.relayUrl);
  String? _err;
  bool _saved = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _c.text.trim();
    if (raw.isEmpty) {
      await Store.i.put('relayUrl', '');
      setState(() {
        _err = null;
        _saved = true;
      });
      return;
    }
    final u = normalizeRelayUrl(raw);
    if (u == null) {
      setState(() {
        _err = 'آدرس باید با wss:// یا https:// شروع شود.';
        _saved = false;
      });
      return;
    }
    _c.text = u;
    await Store.i.put('relayUrl', u);
    setState(() {
      _err = null;
      _saved = true;
    });
  }

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SecTitle('سرور بازی آنلاین'),
          Text(
            kRelayUrl.isEmpty
                ? 'برای بازی از راه دور، آدرس سرور واسطه را اینجا وارد کنید (راهنما در پوشه relay).'
                : 'یک سرور پیش‌فرض داخل برنامه تنظیم شده است. اگر چیزی ننویسید همان استفاده می‌شود.',
            style: ts(11, color: C.muted, h: 1.7),
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _c,
              keyboardType: TextInputType.url,
              autocorrect: false,
              onChanged: (_) => setState(() => _saved = false),
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(hintText: 'wss://case007-relay.name.workers.dev', errorText: _err),
            ),
          ),
          const SizedBox(height: 10),
          AppBtn(_saved ? 'ذخیره شد' : 'ذخیره', icon: _saved ? Icons.check : Icons.save_outlined, kind: BtnKind.ghost, height: 44, onTap: _save),
        ]),
      );
}
