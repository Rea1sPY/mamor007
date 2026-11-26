import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/util.dart';
import '../../game/prints.dart';
import '../../network/client.dart';
import '../../widgets/fingerprint_art.dart';
import '../../widgets/hud.dart';
import '../../widgets/ui.dart';

class LabTab extends StatefulWidget {
  const LabTab({super.key});

  @override
  State<LabTab> createState() => _LabTabState();
}

class _LabTabState extends State<LabTab> {
  final cl = GameClient.i;
  String? _pid;
  String? _who;

  Color _vc(String v) {
    switch (v) {
      case 'match':
        return C.red;
      case 'maybe':
        return C.amber;
      case 'unusable':
        return C.dim;
      default:
        return C.green;
    }
  }

  String _vl(String v) {
    switch (v) {
      case 'match':
        return 'تطابق';
      case 'maybe':
        return 'نامطمئن';
      case 'unusable':
        return 'غیرقابل‌استفاده';
      default:
        return 'عدم تطابق';
    }
  }

  @override
  Widget build(BuildContext context) {
    final prints = cl.evidence.where((e) => e['type'] == 'print').toList();
    final people = <MapEntry<String, String>>[
      const MapEntry('victim', 'قربانی / صاحب محل'),
      for (final s in cl.suspects)
        if (cl.samples.contains(s['id'])) MapEntry('${s['id']}', '${s['name']}'),
    ];
    if (prints.isEmpty && cl.labLog.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('هنوز اثر انگشتی در اختیار شما نیست. اگر هم‌تیمی‌ها اثری پیدا کردند، با اشتراک‌گذاری برای همه نمایش داده می‌شود.',
              textAlign: TextAlign.center, style: ts(13, color: C.muted, h: 1.9)),
        ),
      );
    }
    final ready = _pid != null && _who != null && cl.labLeft > 0;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Panel(
        accent: cl.labLeft > 0 ? C.blue : C.red,
        child: Row(children: [
          const Icon(Icons.biotech_outlined, color: C.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text('اعتبار آزمایشگاه تیم: ${fa(cl.labLeft)} مقایسه. هر درخواست قابل‌برگشت نیست؛ هوشمندانه انتخاب کنید.',
                style: ts(12, h: 1.7)),
          ),
        ]),
      ),
      const SecTitle('اثرهای کشف‌شده'),
      if (prints.isEmpty) Text('اثری در اختیار شما نیست.', style: ts(12, color: C.muted)),
      SizedBox(
        height: 190,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final e in prints)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: GestureDetector(
                onTap: () => setState(() => _pid = '${e['id']}'),
                child: Column(children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _pid == e['id'] ? C.red : Colors.transparent, width: 2),
                    ),
                    child: FingerprintArt(
                      pattern: '${(e['print'] as Map)['p']}',
                      seed: ((e['print'] as Map)['s'] as num).toInt(),
                      quality: '${(e['print'] as Map)['q']}',
                      size: 120,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 130,
                    child: Text('${e['title']}', maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: ts(11, w: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
        ]),
      ),
      const SecTitle('نمونه‌های موجود'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final p in people)
          ChoiceChip(
            label: Text(p.value),
            selected: _who == p.key,
            onSelected: (_) => setState(() => _who = p.key),
            selectedColor: C.red.withAlpha(50),
            backgroundColor: C.panel2,
            showCheckmark: false,
            avatar: Icon(Icons.fingerprint, size: 16, color: _who == p.key ? C.red : C.muted),
            side: BorderSide(color: _who == p.key ? C.red : C.line2),
          ),
      ]),
      if (cl.samples.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('برای مقایسه با یک مظنون، از تب بازجویی از او نمونهٔ اثر انگشت بگیرید.', style: ts(11, color: C.muted, h: 1.7)),
        ),
      const SizedBox(height: 12),
      AppBtn('ارسال به آزمایشگاه', icon: Icons.science_outlined, onTap: ready
          ? () {
              cl.sendLab(_pid!, _who!);
            }
          : null),
      const SecTitle('نتایج آزمایشگاه'),
      if (cl.labLog.isEmpty) Text('هنوز نتیجه‌ای نیست.', style: ts(12, color: C.muted)),
      for (final r in cl.labLog.reversed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            accent: _vc('${r['verdict']}'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${r['title']}  ⟷  ${r['name']}', style: ts(13, w: FontWeight.w800))),
                Tag(_vl('${r['verdict']}'), color: _vc('${r['verdict']}')),
              ]),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                FingerprintArt(
                  pattern: '${(r['pp'] as Map)['p']}',
                  seed: ((r['pp'] as Map)['s'] as num).toInt(),
                  quality: '${(r['pp'] as Map)['q']}',
                  size: 90,
                ),
                const SizedBox(width: 14),
                MatchBridge(verdict: '${r['verdict']}', color: _vc('${r['verdict']}'), seed: seedOf('${r['title']}${r['name']}')),
                const SizedBox(width: 14),
                FingerprintArt(
                  pattern: '${(r['sp'] as Map)['p']}',
                  seed: ((r['sp'] as Map)['s'] as num).toInt(),
                  size: 90,
                  color: C.green,
                ),
              ]),
              const SizedBox(height: 10),
              Text('${r['text']}', style: ts(12, color: C.muted, h: 1.8)),
              const SizedBox(height: 4),
              Text('درخواست از: ${r['by']} · الگوی اثر: ${printPatternFa[(r['pp'] as Map)['p']] ?? ''}', style: ts(10, color: C.dim)),
            ]),
          ),
        ),
    ]);
  }
}
