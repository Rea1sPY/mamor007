import 'package:flutter/material.dart';

import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../network/client.dart';
import '../../widgets/brand.dart';
import '../../widgets/effects.dart';
import '../../widgets/ui.dart';

class BriefingView extends StatelessWidget {
  const BriefingView({super.key});

  @override
  Widget build(BuildContext context) {
    final cl = GameClient.i;
    final intel = cl.intel;
    if (intel == null) return const LoadingScreen(label: 'دریافت پرونده محرمانه…');
    final ready = cl.me?['ready'] == true;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Stack(alignment: Alignment.center, children: [
        Column(children: [
          const SizedBox(height: 6),
          Text('پرونده محرمانه شخصی', style: ts(12, color: C.muted)),
          const SizedBox(height: 4),
          GlitchEffect(child: Text('${intel['title']}', style: ts(24, w: FontWeight.w900), textAlign: TextAlign.center)),
        ]),
        Positioned(
          left: 0,
          top: 0,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 2.2, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(opacity: (2.2 - t).clamp(0, 1).toDouble(), child: Transform.scale(scale: t, child: child)),
            child: const TopSecretStamp(size: 12),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      AgentIdCard(name: Store.i.codename, code: Store.i.agent, rankIdx: Store.i.rank.idx, role: '${intel['role']}'),
      const SecTitle('نقش شما'),
      Panel(
        accent: C.blue,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${intel['role']}', style: ts(16, w: FontWeight.w800, color: C.blue)),
          const SizedBox(height: 6),
          Text('${intel['roleDesc']}', style: ts(13, color: C.muted, h: 1.8)),
        ]),
      ),
      const SecTitle('خلاصه پرونده'),
      Panel(child: Text('${intel['brief']}', style: ts(14, h: 1.9))),
      const SecTitle('اطلاعات اختصاصی شما'),
      Panel(
        accent: C.red,
        child: Row(children: [
          const Icon(Icons.lock_outline, color: C.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'شما ${fa(cl.evidence.length)} مدرک اختصاصی یا عمومی در اختیار دارید. هیچ‌کس اطلاعات کامل ندارد؛ مدارک را با بقیه به اشتراک بگذارید و گفتگو کنید.',
              style: ts(13, color: C.muted, h: 1.8),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      if (!ready)
        AppBtn('فهمیدم، شروع بررسی', icon: Icons.manage_search, onTap: () => cl.setReady(true))
      else
        Panel(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: C.blue)),
            const SizedBox(width: 12),
            Text('منتظر بقیه بازیکنان ${fa(cl.done)} / ${fa(cl.total)}', style: ts(13, color: C.muted)),
          ]),
        ),
    ]);
  }
}
