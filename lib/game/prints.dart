import 'dart:math';

import '../core/util.dart';

const printPatterns = ['loop', 'whorl', 'arch'];
const printPatternFa = {'loop': 'حلقوی', 'whorl': 'مارپیچی', 'arch': 'قوسی'};
const printQualityFa = {'clear': 'واضح', 'partial': 'ناقص', 'smudged': 'لکه‌دار'};

/// A random finger: pattern type + seed that drives the ridge drawing.
J newFinger(Random r) => {'p': printPatterns[r.nextInt(printPatterns.length)], 's': r.nextInt(1 << 30)};

/// Compares a scene print with a sample. [sameOwner] is the hidden truth.
/// Verdicts: match, maybe, no, unusable.
J labCompare(J scene, J sample, bool sameOwner, Random rnd) {
  final q = '${scene['q']}';
  final samePattern = scene['p'] == sample['p'];
  if (q == 'smudged') {
    return {'verdict': 'unusable', 'pct': 0, 'pts': 2 + rnd.nextInt(3)};
  }
  if (sameOwner) {
    if (q == 'clear') return {'verdict': 'match', 'pct': 99, 'pts': 14 + rnd.nextInt(6)};
    return {'verdict': 'match', 'pct': 74 + rnd.nextInt(17), 'pts': 8 + rnd.nextInt(4)};
  }
  if (!samePattern) return {'verdict': 'no', 'pct': 0, 'pts': 1 + rnd.nextInt(3)};
  if (q == 'clear') return {'verdict': 'no', 'pct': 0, 'pts': 3 + rnd.nextInt(3)};
  return {'verdict': 'maybe', 'pct': 28 + rnd.nextInt(25), 'pts': 5 + rnd.nextInt(3)};
}

String labText(J r, String who) {
  final pts = fa(r['pts']);
  final pct = fa(r['pct']);
  switch ('${r['verdict']}') {
    case 'match':
      return r['pct'] == 99
          ? 'تطابق قطعی: $pts نقطهٔ مشخصه بین اثر کشف‌شده و نمونهٔ $who منطبق است.'
          : 'تطابق احتمالی با اطمینان $pct٪: $pts نقطهٔ مشخصه منطبق است؛ اثر ناقص بوده و نتیجه قطعی نیست.';
    case 'maybe':
      return 'الگوی کلی مشابه است اما فقط $pts نقطه منطبق شد (شباهت $pct٪). نمونهٔ $who را نمی‌توان تأیید یا رد کرد.';
    case 'unusable':
      return 'کیفیت اثر کشف‌شده برای مقایسه کافی نیست؛ نتیجه‌ای دربارهٔ $who قابل‌اعلام نیست.';
    default:
      return 'عدم تطابق: اثر کشف‌شده متعلق به نمونهٔ $who نیست.';
  }
}
