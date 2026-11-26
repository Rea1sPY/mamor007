import 'package:flutter/material.dart';

/// Cosmetic badges. They unlock nothing; they only show progress.
class Badge007 {
  const Badge007(this.title, this.desc, this.icon, this.earned);
  final String title;
  final String desc;
  final IconData icon;
  final bool earned;
}

List<Badge007> badgesFor({
  required int wins,
  required int played,
  required int lost,
  required int bestStreak,
  required int rankIdx,
  required int winRatePct,
}) =>
    [
      Badge007('اولین پرونده', 'یک پرونده را حل کنید', Icons.flag_outlined, wins >= 1),
      Badge007('کارآگاه پرکار', 'پنج پرونده را حل کنید', Icons.military_tech_outlined, wins >= 5),
      Badge007('استاد پرونده‌ها', 'ده پرونده را حل کنید', Icons.workspace_premium_outlined, wins >= 10),
      Badge007('سه برد پیاپی', 'سه پرونده پشت سر هم حل کنید', Icons.local_fire_department_outlined, bestStreak >= 3),
      Badge007('درس از شکست', 'یک پرونده را ببازید و ادامه دهید', Icons.school_outlined, lost >= 1),
      Badge007('کهنه‌کار', 'ده پرونده را ببندید', Icons.history_edu_outlined, played >= 10),
      Badge007('دقیق و بی‌خطا', 'با حداقل ۵ پرونده، نرخ حل بالای ۶۰٪', Icons.gps_fixed, played >= 5 && winRatePct >= 60),
      Badge007('رئیس واحد', 'به بالاترین رتبه برسید', Icons.shield_outlined, rankIdx >= 3),
    ];
