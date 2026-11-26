import 'package:flutter/material.dart';

import '../../core/feedback.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../network/client.dart';
import '../../widgets/brand.dart';
import '../../widgets/hud.dart';
import '../../widgets/ui.dart';

class ResultView extends StatelessWidget {
  const ResultView({super.key});

  @override
  Widget build(BuildContext context) {
    final cl = GameClient.i;
    final r = cl.result;
    if (r == null) return const LoadingScreen(label: 'اعلام نتیجه…');
    final sol = Map<String, dynamic>.from(r['solution'] as Map);
    final rows = asList(r['rows']);
    final won = r['won'] == true;
    final verdict = r['verdict'];
    final culprit = '${sol['culprit']}';
    return ListView(padding: const EdgeInsets.all(16), children: [
      FxOnMount(action: won ? Fx.success : Fx.fail, child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
      Positioned.fill(
        child: OverflowBox(
          maxWidth: 340,
          maxHeight: 340,
          child: IgnorePointer(
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [(won ? C.green : C.red).withAlpha(70), Colors.transparent]),
              ),
            ),
          ),
        ),
      ),
      Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 2.4, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(opacity: (2.4 - t).clamp(0, 1).toDouble(), child: Transform.scale(scale: t, child: child)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: TopSecretStamp(text: won ? 'CASE SOLVED' : 'CASE LOST', size: 26, color: won ? C.green : C.red),
          ),
        ),
      ),
      ])),
      Panel(
        accent: won ? C.green : C.red,
        child: Text(
          verdict == null
              ? 'هیچ نتیجه‌ای ثبت نشد. پرونده بایگانی شد و مجرم آزاد ماند. این پرونده دیگر باز نمی‌شود.'
              : won
                  ? 'حکم تیم: ${cl.suspectName('$verdict')}. درست بود! ${cl.suspectName(culprit)} بازداشت شد و پرونده برای همیشه بسته شد.'
                  : 'حکم تیم: ${cl.suspectName('$verdict')}. اشتباه بود! یک بی‌گناه بازداشت شد و ${cl.suspectName(culprit)} آزاد ماند. این پرونده باخته شد و دیگر باز نمی‌شود.',
          style: ts(14, h: 1.9, w: FontWeight.w700),
        ),
      ),
      const SecTitle('حقیقت پرونده'),
      Reveal(index: 3, child: Panel(
        accent: C.red,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.person_search, color: C.red),
            const SizedBox(width: 8),
            Text('مجرم واقعی: ${cl.suspectName(culprit)}', style: ts(17, w: FontWeight.w800, color: C.red)),
          ]),
          const SizedBox(height: 8),
          Text('انگیزه: ${cl.motiveText('${sol['motive']}')}', style: ts(14, w: FontWeight.w600)),
          const SizedBox(height: 10),
          Text('${sol['explanation']}', style: ts(13, color: C.muted, h: 1.9)),
          const SizedBox(height: 10),
          Text('مدارک کلیدی', style: ts(12, color: C.muted)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in asList(sol['keyEvidence'])) Tag('${e['title']}', color: C.amber),
          ]),
        ]),
      )),
      const SecTitle('نظریه‌های اعضا'),
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Panel(
            accent: row['submitted'] == true && (row['grade'] as Map)['culprit'] == true ? C.green : null,
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${row['name']}', style: ts(15, w: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    row['submitted'] == true
                        ? 'متهم: ${cl.suspectName('${row['suspect']}')} · ${(row['grade'] as Map)['culprit'] == true ? 'درست' : 'نادرست'} · انگیزه ${(row['grade'] as Map)['motive'] == true ? 'درست' : 'نادرست'} · رأی ${fa(row['votes'])}'
                        : 'نظریه ثبت نکرد',
                    style: ts(11, color: C.muted, h: 1.6),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      const SizedBox(height: 8),
      ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) => Panel(
          accent: C.blue,
          child: Row(children: [
            const Icon(Icons.folder_special_outlined, color: C.blue),
            const SizedBox(width: 10),
            Expanded(child: Text('پرونده‌های حل‌شده شما: ${fa(Store.i.solved.length)}', style: ts(14, w: FontWeight.w700))),
            Tag(Store.i.rank.name, color: C.green),
          ]),
        ),
      ),
      if (cl.rankedUp) ...[
        const SizedBox(height: 10),
        const SystemNotice('ارتقای رتبه! رتبه جدید شما ثبت شد.', icon: Icons.military_tech_outlined, color: C.amber),
      ],
      const SizedBox(height: 16),
      if (cl.isHost)
        AppBtn('بازگشت به لابی', icon: Icons.replay, onTap: cl.hostToLobby)
      else
        Panel(child: Text('منتظر بازگشت میزبان به لابی…', textAlign: TextAlign.center, style: ts(13, color: C.muted))),
      const SizedBox(height: 10),
      AppBtn('خروج', icon: Icons.logout, kind: BtnKind.ghost, onTap: () async {
        await cl.leave();
        if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      }),
    ]);
  }
}
