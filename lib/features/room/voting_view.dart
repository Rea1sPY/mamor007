import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/util.dart';
import '../../network/client.dart';
import '../../widgets/hud.dart';
import '../../widgets/ui.dart';

class VotingView extends StatelessWidget {
  const VotingView({super.key});

  @override
  Widget build(BuildContext context) {
    final cl = GameClient.i;
    final others = cl.hyps.where((h) => h['pid'] != cl.myPid).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SecTitle('رأی‌گیری'),
      Text('به نظریه‌ای که منطقی‌تر است رأی بدهید. به نظریه خودتان نمی‌توانید رأی بدهید.', style: ts(13, color: C.muted, h: 1.7)),
      const SizedBox(height: 12),
      if (others.isEmpty)
        const Panel(child: Text('نظریه‌ای برای رأی‌دادن وجود ندارد. نتیجه در حال محاسبه است.'))
      else
        for (final h in others)
          Reveal(index: others.indexOf(h), child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              accent: C.blue,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.person_outline, color: C.blue, size: 18),
                  const SizedBox(width: 6),
                  Text('نظریه ${h['name']}', style: ts(15, w: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                _Row('متهم', cl.suspectName('${h['suspect']}')),
                _Row('انگیزه', cl.motiveText('${h['motive']}')),
                _Row('مدارک', asList(h['evidence']).map((e) => '${e['title']}').join('، ')),
                if ('${h['reasoning']}'.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('${h['reasoning']}', style: ts(13, color: C.muted, h: 1.8)),
                ],
                const SizedBox(height: 12),
                if (!cl.voted) AppBtn('رأی به این نظریه', icon: Icons.how_to_vote_outlined, height: 46, onTap: () async {
                  final ok = await confirm(context, 'ثبت رأی', 'رأی شما به نظریه ${h['name']} ثبت می‌شود و قابل تغییر نیست.', yes: 'ثبت رأی');
                  if (ok) cl.vote('${h['pid']}');
                }),
              ]),
            ),
          )),
      if (cl.voted)
        Panel(
          accent: C.green,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle_outline, color: C.green),
            const SizedBox(width: 10),
            Text('رأی ثبت شد · ${fa(cl.done)} / ${fa(cl.total)}', style: ts(13, color: C.muted)),
          ]),
        ),
      if (cl.isHost) ...[
        const SizedBox(height: 12),
        AppBtn('اعلام نتیجه', icon: Icons.flag_outlined, kind: BtnKind.ghost, onTap: () async {
          if (cl.done < cl.total) {
            final ok = await confirm(context, 'اعلام نتیجه', 'همه رأی نداده‌اند. ادامه می‌دهید؟');
            if (!ok) return;
          }
          cl.hostAdvance();
        }),
      ],
    ]);
  }
}

class _Row extends StatelessWidget {
  const _Row(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 50, child: Text(k, style: ts(12, color: C.muted))),
          Expanded(child: Text(v, style: ts(13, w: FontWeight.w600))),
        ]),
      );
}
