import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../game/case_model.dart';
import '../network/client.dart';
import '../widgets/brand.dart';
import '../widgets/hud.dart';
import '../widgets/ui.dart';
import 'create_room.dart';
import 'guide_screen.dart';
import 'info_screens.dart';
import 'join_room.dart';
import 'room/room_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  Future<void> _resume(BuildContext context) async {
    final s = Store.i.session;
    if (s == null) return;
    final err = await GameClient.i.join(
      ip: '${s['ip']}',
      port: (s['port'] as num).toInt(),
      code: '${s['code']}',
      savedToken: '${s['token']}',
      relay: '${s['relay'] ?? ''}',
    );
    if (!context.mounted) return;
    if (err != null) {
      await Store.i.clearSession();
      if (context.mounted) snack(context, err);
      return;
    }
    Navigator.of(context).push(fxRoute(const RoomScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Stage(
      back: false,
      child: ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          final next = s.nextRank;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Reveal(
                index: 0,
                child: Row(children: [
                  const CaseLogo(size: 40, showText: false),
                  const SizedBox(width: 10),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('CASE 007', style: ts(18, w: FontWeight.w900, ls: 3)),
                      Text('DETECTIVE NETWORK', style: ts(9, color: C.blue, w: FontWeight.w700, ls: 2.5)),
                    ]),
                  ),
                  const Spacer(),
                  HudIconBtn(
                    tooltip: 'تنظیمات',
                    icon: Icons.settings_outlined,
                    onTap: () => Navigator.of(context).push(fxRoute(const SettingsScreen())),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              const Reveal(
                index: 1,
                child: SystemNotice('همه سامانه‌ها آماده‌اند. بازی بدون اینترنت و روی شبکه محلی اجرا می‌شود.'),
              ),
              const SizedBox(height: 14),
              Reveal(index: 2, child: AgentIdCard(name: s.codename, code: s.agent, rankIdx: s.rank.idx)),
              const SizedBox(height: 12),
              Reveal(
                index: 3,
                child: RankBar(
                  value: next == null ? 1.0 : (s.solved.length - s.rank.min) / (next.min - s.rank.min),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                next == null ? 'بالاترین رتبه · ${fa(s.solved.length)} پرونده حل‌شده' : '${fa(s.solved.length)} / ${fa(next.min)} پرونده حل‌شده تا ${next.name}',
                style: ts(11, color: C.muted),
              ),
              if (s.session != null) ...[
                const SizedBox(height: 14),
                AppBtn('بازگشت به اتاق قبلی', icon: Icons.replay, kind: BtnKind.ghost, onTap: () => _resume(context)),
              ],
              const SizedBox(height: 18),
              const Reveal(index: 4, child: HudDivider('MISSION CONTROL')),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  Reveal(
                    index: 5,
                    child: MenuTile(
                      art: GIcon.room,
                      title: 'ساخت اتاق',
                      sub: 'میزبان بازی شوید',
                      color: C.red,
                      no: '01',
                      onTap: () => Navigator.of(context).push(fxRoute(const CreateRoomScreen())),
                    ),
                  ),
                  Reveal(
                    index: 6,
                    child: MenuTile(
                      art: GIcon.join,
                      title: 'ورود به اتاق',
                      sub: 'با کد یا QR',
                      color: C.blue,
                      no: '02',
                      onTap: () => Navigator.of(context).push(fxRoute(const JoinRoomScreen())),
                    ),
                  ),
                  Reveal(
                    index: 7,
                    child: MenuTile(
                      art: GIcon.cases,
                      title: 'پرونده‌ها',
                      sub: 'فهرست پرونده‌ها',
                      color: C.amber,
                      no: '03',
                      onTap: () => Navigator.of(context).push(fxRoute(const CasesScreen())),
                    ),
                  ),
                  Reveal(
                    index: 8,
                    child: MenuTile(
                      art: GIcon.profile,
                      title: 'پروفایل',
                      sub: 'آمار و رتبه',
                      color: C.green,
                      no: '04',
                      onTap: () => Navigator.of(context).push(fxRoute(const ProfileScreen())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppBtn(
                s.guideSeen ? 'راهنمای بازی' : 'اولین بار است؟ راهنمای بازی',
                icon: Icons.menu_book_outlined,
                kind: s.guideSeen ? BtnKind.ghost : BtnKind.primary,
                onTap: () => Navigator.of(context).push(fxRoute(const GuideScreen())),
              ),
              const SizedBox(height: 10),
              Row(children: [
                const Expanded(child: SupportButton()),
                const SizedBox(width: 10),
                Expanded(
                  child: AppBtn('درباره', icon: Icons.info_outline, kind: BtnKind.ghost,
                      onTap: () => Navigator.of(context).push(fxRoute(const AboutScreen()))),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }
}

Future<List<CaseData>> loadCases() => CaseLoader.loadAll();
