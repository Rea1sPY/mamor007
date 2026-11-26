import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../widgets/hud.dart';
import '../widgets/ui.dart';

/// In-app manual. Opening it once clears the "first time?" highlight on the menu.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _Step {
  const _Step(this.icon, this.color, this.title, this.body);
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

class _GuideScreenState extends State<GuideScreen> {
  static const _phases = [
    _Step(Icons.meeting_room_outlined, C.blue, 'لابی',
        'میزبان اتاق را می‌سازد و کد ۶ حرفی یا QR را پخش می‌کند. بقیه فقط کد را وارد می‌کنند؛ آدرس شبکه لازم نیست. همه روی «آماده‌ام» می‌زنند و میزبان بازی را شروع می‌کند.'),
    _Step(Icons.assignment_outlined, C.amber, 'جلسه توجیهی',
        'خلاصه پرونده، فهرست مظنونان و نقش مخفی شما نمایش داده می‌شود. نقش شما مشخص می‌کند از چه زاویه‌ای باید به پرونده نگاه کنید.'),
    _Step(Icons.search, C.red, 'بررسی',
        'مدارک بین بازیکنان تقسیم شده است و هر مدرک خصوصی فقط یک صاحب دارد. مدرک‌هایتان را بخوانید، آن‌ها را برای تیم «به اشتراک بگذارید» و با بقیه گفتگو کنید.'),
    _Step(Icons.gavel, C.amber, 'نظریه',
        'هر بازیکن یک نظریه ثبت می‌کند: متهم، انگیزه و مدارک کلیدی. فقط یک نظریه برای هر نفر پذیرفته می‌شود.'),
    _Step(Icons.how_to_vote_outlined, C.green, 'رأی‌گیری',
        'همه نظریه‌های ثبت‌شده را می‌بینند و به یکی رأی می‌دهند. متهمی که بیشترین رأی را بیاورد حکم تیم است.'),
    _Step(Icons.flag_outlined, C.red, 'نتیجه',
        'حقیقت پرونده فاش می‌شود. اگر حکم تیم مجرم واقعی باشد پرونده حل شده و در غیر این صورت باخته است. هر پرونده یک بار بسته می‌شود و دوباره باز نمی‌شود.'),
  ];

  static const _tabs = [
    _Step(Icons.dashboard_customize_outlined, C.blue, 'میز تحقیقات',
        'همه مدارک روی یک تخته. با کشیدن، مدارک را کنار هم بچینید و با خط به هم وصل کنید تا ارتباط‌ها دیده شوند.'),
    _Step(Icons.description_outlined, C.red, 'اسناد',
        'اسناد و یادداشت‌های مدارک شما. هر سند را باز کنید و اگر برای تیم مهم است، ارسال کنید.'),
    _Step(Icons.photo_library_outlined, C.amber, 'تصاویر',
        'عکس‌های صحنه. به جزئیات توجه کنید؛ گاهی یک سایه یا یک شیء جابه‌جاشده کل روایت را عوض می‌کند.'),
    _Step(Icons.record_voice_over_outlined, C.green, 'بازجویی',
        'یک مظنون یا شاهد را انتخاب کنید، لحن را تعیین کنید و موضوع بپرسید. جواب فقط به شما نمایش داده می‌شود؛ برای تیم بازگو کنید.'),
    _Step(Icons.fingerprint, C.blue, 'آزمایشگاه',
        'اثر انگشت یک مدرک را با نمونه یک مظنون مقایسه کنید. تعداد درخواست‌های آزمایشگاه برای کل تیم محدود است، پس با هم هماهنگ باشید.'),
    _Step(Icons.forum_outlined, C.muted, 'گفتگو',
        'گفتگوی متنی تیم. دکمه دفترچه (بالای صفحه بررسی) یادداشت خصوصی شماست و برای هیچ‌کس فرستاده نمی‌شود.'),
  ];

  static const _tips = [
    (Icons.psychology_alt_outlined, 'عصبی‌بودن مدرک گناه نیست', 'آدم‌های بی‌گناه هم زیر فشار می‌لرزند. جواب‌ها را با مدارک بسنجید، نه با لحن.'),
    (Icons.compare_arrows, 'دنبال ناهماهنگی بگردید', 'یک سؤال را در دو لحن یا از دو زاویه بپرسید. دروغ معمولاً در جزئیات تغییر می‌کند.'),
    (Icons.favorite_border, 'همدلی گاهی بهتر از فشار است', 'فشار زیاد ممکن است مظنون را به درخواست وکیل بکشاند و دیگر جوابی نگیرید.'),
    (Icons.share_outlined, 'مدرک را پنهان نکنید', 'هر مدرک خصوصی فقط پیش یک نفر است. اگر نگویید، تیم هرگز آن را نمی‌بیند.'),
    (Icons.fingerprint, 'درخواست آزمایشگاه را حساب‌شده خرج کنید', 'اول مدارک اثر انگشت‌دار مهم را انتخاب کنید و بعد نمونه‌گیری کنید.'),
    (Icons.edit_note, 'یادداشت بردارید', 'ساعت‌ها، نام‌ها و تناقض‌ها را در دفترچه بنویسید تا موقع ثبت نظریه از دست نروند.'),
  ];

  static const _network = [
    'اگر بازیکنی اتاق را پیدا نمی‌کند، همه گوشی‌ها باید روی یک شبکه باشند. هات‌اسپات گوشی میزبان بهترین گزینه است.',
    'وای‌فای مهمان و بعضی مودم‌ها ارتباط بین دستگاه‌ها را مسدود می‌کنند؛ در این حالت هات‌اسپات را امتحان کنید.',
    'برنامه میزبان باید در حال اجرا و روی صفحه بماند. اگر برنامه بسته شود، بازی برای همه تمام می‌شود.',
    'اگر اتصال یک بازیکن قطع شد، تا ۹۰ ثانیه فرصت دارد برگردد و از دکمه «بازگشت به اتاق قبلی» در منو استفاده کند.',
    'بعد از شروع بازی دیگر نمی‌توان وارد اتاق شد.',
    'برای بازی از راه دور: میزبان در ساخت اتاق «اتاق آنلاین» را روشن می‌کند و بقیه در ورود به اتاق گزینه «آنلاین» را می‌زنند. به آدرس سرور آنلاین در تنظیمات نیاز است.',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !Store.i.guideSeen) Store.i.put('guideSeen', true);
    });
  }

  Widget _stepCard(_Step s, int n, {bool numbered = true}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Panel(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: s.color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: s.color.withAlpha(120)),
              ),
              child: Icon(s.icon, color: s.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(numbered ? '${fa(n)}. ${s.title}' : s.title, style: ts(14, w: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(s.body, style: ts(12, color: C.muted, h: 1.8)),
              ]),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    var i = 0;
    return Stage(
      title: 'راهنمای بازی',
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
        Reveal(
          index: i++,
          child: Panel(
            accent: C.red,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('هدف بازی', style: ts(16, w: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'شما و هم‌تیمی‌هایتان یک گروه کارآگاه هستید. با بررسی مدارک و بازجویی از مظنونان باید مجرم واقعی را پیدا کنید. بازی یک شات دارد: یا مجرم درست دستگیر می‌شود و پرونده حل می‌شود، یا یک بی‌گناه بازداشت می‌شود و پرونده می‌سوزد.',
                style: ts(13, color: C.muted, h: 1.9),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: const [
                Tag('۲ تا ۶ بازیکن', icon: Icons.groups_outlined),
                Tag('بدون اینترنت', color: C.green, icon: Icons.wifi_off),
                Tag('پرونده‌های نامحدود', color: C.amber, icon: Icons.all_inclusive),
              ]),
            ]),
          ),
        ),
        Reveal(index: i++, child: const SecTitle('مراحل بازی')),
        for (var k = 0; k < _phases.length; k++) Reveal(index: i++, child: _stepCard(_phases[k], k + 1)),
        Reveal(index: i++, child: const SecTitle('بخش‌های مرحله بررسی')),
        for (final t in _tabs) Reveal(index: i++, child: _stepCard(t, 0, numbered: false)),
        Reveal(index: i++, child: const SecTitle('نکات کارآگاهی')),
        for (final t in _tips)
          Reveal(
            index: i++,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(t.$1, color: C.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.$2, style: ts(13, w: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(t.$3, style: ts(12, color: C.muted, h: 1.8)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        Reveal(index: i++, child: const SecTitle('مشکل در اتصال؟')),
        Reveal(
          index: i++,
          child: Panel(
            accent: C.blue,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final n in _network)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, left: 8),
                      child: Icon(Icons.circle, size: 6, color: C.blue),
                    ),
                    Expanded(child: Text(n, style: ts(12, color: C.muted, h: 1.8))),
                  ]),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        const HudDivider('GOOD LUCK, AGENT'),
      ]),
    );
  }
}
