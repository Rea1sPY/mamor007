import 'dart:math';

import '../core/util.dart';
import 'gen_data.dart';
import 'prints.dart';
import 'voice.dart';

String _f(String s, Map<String, String> m) {
  var out = s;
  m.forEach((k, v) {
    out = out.replaceAll('{$k}', v);
  });
  return out;
}

String _hm(int minutes) {
  final t = ((minutes % 1440) + 1440) % 1440;
  final h = (t ~/ 60).toString().padLeft(2, '0');
  final m = (t % 60).toString().padLeft(2, '0');
  return fa('$h:$m');
}

String _hmA(int minutes) {
  final t = ((minutes % 1440) + 1440) % 1440;
  final h = (t ~/ 60).toString().padLeft(2, '0');
  final m = (t % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

class _P {
  _P(this.id, this.first, this.last, this.role, this.bio);
  final String id;
  final String first;
  final String last;
  final String role;
  final String bio;
  String get full => '$first $last';
  String height = '';
  String outfit = '';
  String zone = ''; // where the person really was at the crime time
  String claimZone = ''; // where the person says they were
  String secretKind = ''; // empty = no secret
  int motive = -1; // apparent motive index (friction)
  bool culprit = false;
  bool liar = false;
  bool friction = false;
}

class _Ev {
  _Ev(this.key, this.type, this.title, this.content,
      {this.public = false, this.scene = '', this.caption = '', this.print});
  final String key;
  final String type;
  final String title;
  final String content;
  final bool public;
  final String scene;
  final String caption;
  final J? print;
}

class CaseGenerator {
  static const categories = ['murder', 'theft', 'espionage'];

  /// Builds one complete case. Same [seed] gives the same case.
  static J generate({String category = 'random', String difficulty = 'standard', int? seed}) {
    final sd = seed ?? Random.secure().nextInt(0x7ffffff0);
    final r = Random(sd);
    final diff = const ['easy', 'standard', 'hard'].contains(difficulty) ? difficulty : 'standard';
    final cat = categories.contains(category) ? category : categories[r.nextInt(categories.length)];
    final pool = scenarios.where((s) => s.cat == cat).toList();
    final scn = pool[r.nextInt(pool.length)];

    final nSus = diff == 'easy' ? 4 : (diff == 'standard' ? 5 : 6);
    final nLiars = diff == 'easy' ? 1 : (diff == 'standard' ? 2 : 3);
    final nFric = diff == 'easy' ? 1 : 2;
    final nClear = diff == 'hard' ? 2 : 1;
    final nNoise = diff == 'easy' ? 0 : (diff == 'standard' ? 1 : 2);
    final nWit = diff == 'hard' ? 2 : 1;

    // ---- cast -------------------------------------------------------------
    final firstM = [...maleNames]..shuffle(r);
    final firstF = [...femaleNames]..shuffle(r);
    final lasts = [...lastNames]..shuffle(r);
    var im = 0;
    var jf = 0;
    var il = 0;
    String nextFirst() => r.nextBool() ? firstM[im++ % firstM.length] : firstF[jf++ % firstF.length];
    String nextLast() => lasts[il++ % lasts.length];

    final victimFirst = nextFirst();
    final victimLast = nextLast();
    final victim = '$victimFirst $victimLast';

    final roles = [...scn.roles]..shuffle(r);
    final people = <_P>[];
    for (var i = 0; i < nSus; i++) {
      people.add(_P('s${i + 1}', nextFirst(), nextLast(), roles[i][0], roles[i][1]));
    }
    final ci = r.nextInt(nSus);
    final culprit = people[ci];
    culprit.culprit = true;
    final innocents = people.where((p) => !p.culprit).toList();

    // appearance: culprit unique; one decoy shares height, another shares outfit
    final hs = [...heights];
    final os = [...outfits]..shuffle(r);
    culprit.height = hs[r.nextInt(hs.length)];
    culprit.outfit = os.first;
    final otherH = hs.where((h) => h != culprit.height).toList();
    final otherO = os.where((o) => o != culprit.outfit).toList();
    final decoyH = innocents[0];
    final decoyO = innocents[1];
    decoyH.height = culprit.height;
    decoyH.outfit = otherO[0];
    decoyO.outfit = culprit.outfit;
    decoyO.height = otherH[r.nextInt(otherH.length)];
    for (var i = 2; i < innocents.length; i++) {
      innocents[i].height = otherH[r.nextInt(otherH.length)];
      innocents[i].outfit = otherO[(i + 1) % otherO.length];
    }

    // zones
    final zones = [...scn.zones]..shuffle(r);
    var zi = 0;
    String nextZone() => zones[zi++ % zones.length];
    culprit.zone = scn.scene;
    for (final p in innocents) {
      p.zone = nextZone();
      p.claimZone = p.zone;
    }
    culprit.claimZone = nextZone();

    // roles in the story
    final shuffled = [...innocents]..shuffle(r);
    final liars = shuffled.take(nLiars).toList();
    final rest = shuffled.skip(nLiars).toList();
    final kinds = secretKinds.keys.toList()..shuffle(r);
    for (var i = 0; i < liars.length; i++) {
      final p = liars[i];
      p.liar = true;
      p.secretKind = kinds[i % kinds.length];
      var cz = nextZone();
      if (cz == p.zone) cz = nextZone();
      p.claimZone = cz;
    }
    final motives = [...(motiveTable[cat]!)];
    final order = List<int>.generate(motives.length, (i) => i)..shuffle(r);
    final culMotive = order[0];
    final candF = [...rest, ...liars]..shuffle(r);
    var fi = 0;
    for (final p in candF.take(nFric)) {
      p.friction = true;
      p.motive = order[1 + (fi % (order.length - 1))];
      fi++;
    }
    final qPerson = (rest.isNotEmpty ? rest : innocents)[r.nextInt(rest.isNotEmpty ? rest.length : innocents.length)];
    final honest = rest.where((p) => p != qPerson).toList();
    final hearer = honest.isNotEmpty ? honest[r.nextInt(honest.length)] : qPerson;

    // ---- time line ----------------------------------------------------------
    final tc = scn.start + 30 + (r.nextInt(max(1, scn.span - 60)) ~/ 5) * 5;
    final tIn = tc - 15;
    final tOut = tc + 10 + r.nextInt(6);
    final tFound = scn.start + scn.span + 20 + r.nextInt(40);
    final tA = tc - 45 - r.nextInt(15);
    final tD = tc + 40 + r.nextInt(15);
    final tQ1 = tc - 95 - r.nextInt(10);
    final tQ2 = tc - 50 - r.nextInt(8);
    final tR = tFound - 8;
    final place = scn.places[r.nextInt(scn.places.length)];
    final vShort = victimFirst;
    final objectTxt = scn.object.isEmpty ? scn.item : scn.object;
    final errand = errands[cat]![r.nextInt(errands[cat]!.length)];

    final slots = <String, String>{
      'place': place,
      'scene': scn.scene,
      'entry': scn.entry,
      'item': scn.item,
      'object': objectTxt,
      'v': vShort,
      'victim': victim,
    };

    // ---- evidence -----------------------------------------------------------
    final evs = <_Ev>[];

    final meansTxt = scn.means[r.nextInt(scn.means.length)];
    String sceneReport;
    if (cat == 'murder') {
      sceneReport =
          '$victim (${scn.victimRole} $place) ساعت ${_hm(tFound)} در ${scn.scene} بی‌جان پیدا شد. $meansTxt. زمان تقریبی رویداد بین ${_hm(scn.start + 20)} و ${_hm(tFound - 10)} برآورد شده است. ${fa(nSus)} نفر آن شب به $place رفت‌وآمد داشتند.';
    } else if (cat == 'theft') {
      sceneReport =
          'ساعت ${_hm(tFound)} مشخص شد ${scn.object} از ${scn.scene} $place ناپدید شده است. $meansTxt. سامانهٔ هشدار در بازهٔ شب بی‌اثر مانده بود. ${fa(nSus)} نفر آن شب به آنجا دسترسی داشتند.';
    } else {
      sceneReport =
          'ساعت ${_hm(tFound)} هشدار نشت اطلاعات از ${scn.scene} $place ثبت شد: ${scn.object} کپی شده است. $meansTxt. ${fa(nSus)} نفر دسترسی داشتند و هیچ ورود غیرمجازی ثبت نشده است.';
    }
    evs.add(_Ev('scene', 'document', 'گزارش صحنه', sceneReport, public: true));

    // K1: access log
    final logLines = <String>[
      '${_hm(tQ1)} ورود با کارت ${qPerson.full}.',
      '${_hm(tQ2)} خروج با کارت ${qPerson.full}.',
      '${_hm(tIn)} ورود با کارت ${culprit.full}.',
      '${_hm(tOut)} خروج با کارت ${culprit.full}.',
      '${_hm(tR)} ورود با کارت ${hearer.full}.',
    ];
    if (diff != 'easy') {
      final other = innocents.firstWhere((p) => p != qPerson && p != hearer, orElse: () => qPerson);
      if (other != qPerson) logLines.insert(2, '${_hm(tc - 130)} ورود و خروج کوتاه با کارت ${other.full}.');
    }
    evs.add(_Ev(
      'log',
      'document',
      'ثبت تردد ${scn.entry}',
      'گزارش کارت‌خوان ${scn.entry}: ${logLines.join(' ')} هیچ گزارش گم‌شدن یا سرقت کارتی ثبت نشده است.',
    ));

    // K2: decisive print
    final fingers = <String, J>{};
    for (final p in people) {
      fingers[p.id] = newFinger(r);
    }
    fingers['victim'] = newFinger(r);
    final qMain = diff == 'easy' ? 'clear' : 'partial';
    final printOwners = <String, String>{}; // key -> owner
    final printMeta = <String, J>{};
    _Ev printEv(String key, String title, String what, String owner, String q) {
      final fg = owner == 'unknown' ? newFinger(r) : fingers[owner]!;
      printOwners[key] = owner;
      final meta = {'p': fg['p'], 's': fg['s'], 'q': q};
      printMeta[key] = meta;
      return _Ev(key, 'print', title,
          'اثر انگشت لیفت‌شده از $what. کیفیت اثر: ${printQualityFa[q]}؛ الگو: ${printPatternFa[fg['p']]}. برای مقایسه به آزمایشگاه ارسال کنید.',
          print: meta);
    }

    evs.add(printEv('pItem', 'اثر انگشت روی ${scn.item}', scn.item, culprit.id, qMain));
    evs.add(printEv('pDoor', 'اثر انگشت روی ${scn.entry}', 'دستگیرهٔ ${scn.entry}', qPerson.id, 'clear'));
    if (diff != 'easy') {
      evs.add(printEv('pVic', 'اثر انگشت روی میز', 'میز داخل ${scn.scene}', 'victim', 'clear'));
    }
    if (diff == 'hard') {
      evs.add(printEv('pUnk', 'اثر انگشت روی قاب در', 'قاب دَرِ ${scn.scene}', 'unknown', 'smudged'));
    }

    // K3: motive document
    final mt = motives[culMotive];
    final motiveSlots = {...slots, 'name': culprit.full};
    evs.add(_Ev('motive', 'document', mt[1], _f(mt[2], motiveSlots)));

    // K4: claim check
    evs.add(_Ev(
      'claim',
      'document',
      'بررسی اظهارات ${culprit.first}',
      '${culprit.full} اظهار کرده از ${_hm(tA)} تا ${_hm(tD)} در ${culprit.claimZone} بوده است. مسئول آن بخش می‌گوید در این بازه او را آنجا ندیده و ثبت حضور و دوربین‌های ${culprit.claimZone} نیز هیچ نشانی از او ندارند.',
    ));

    // photos
    evs.add(_Ev(
      'photoEntry',
      'photo',
      'تصویر دوربین ${scn.entry}',
      'فردی با ${culprit.outfit} ساعت ${_hm(tIn)} از ${scn.entry} عبور می‌کند؛ چهره در سایه است.',
      scene: 'corridor',
      caption: 'CAM · ${_hmA(tIn)}',
    ));
    evs.add(_Ev(
      'photoScene',
      'photo',
      'نمای ${scn.scene}',
      scn.sceneShot,
      scene: 'room',
      caption: 'SCENE · ${_hmA(tFound)}',
    ));

    // secrets of the liars
    final secretKeys = <String, String>{};
    for (final p in liars) {
      final sk = secretKinds[p.secretKind]!;
      final key = 'sec_${p.id}';
      secretKeys[p.id] = key;
      final t = _hm(tc + r.nextInt(7) - 3);
      evs.add(_Ev(key, sk[4], sk[1], _f(sk[2], {'name': p.full, 'zone': p.zone, 't': t})));
    }

    // friction documents (innocents with an apparent motive)
    final fricKeys = <String, String>{};
    for (final p in people.where((p) => p.friction)) {
      final mm = motives[p.motive];
      final key = 'fr_${p.id}';
      fricKeys[p.id] = key;
      evs.add(_Ev(key, 'document', mm[1], _f(mm[2], {...slots, 'name': p.full})));
    }

    // clearing documents for honest innocents
    final clearKeys = <String, String>{};
    final clearPool = honest.where((p) => p != hearer || honest.length == 1).toList()..shuffle(r);
    for (final p in clearPool.take(nClear)) {
      final key = 'clr_${p.id}';
      clearKeys[p.id] = key;
      final src = const ['کارت‌خوان', 'دوربین', 'دفتر ثبت'][r.nextInt(3)];
      evs.add(_Ev(key, 'document', 'ثبت حضور ${p.first}',
          'ثبت حضور: ${p.full} در بازهٔ ${_hm(tc - 10)} تا ${_hm(tc + 10)} در ${p.zone} حضور داشته است (منبع: $src).'));
    }

    // noise
    final noisePool = [...noiseDocs]..shuffle(r);
    for (var i = 0; i < nNoise; i++) {
      final nd = noisePool[i];
      evs.add(_Ev('noise$i', 'document', nd[0],
          _f(nd[1], {'place': place, 'zone': zones[r.nextInt(zones.length)], 't': _hm(tc + r.nextInt(30) - 15)})));
    }

    // shuffle (scene stays first) and assign ids
    final rest2 = evs.sublist(1)..shuffle(r);
    final ordered = [evs.first, ...rest2];
    final idOf = <String, String>{};
    for (var i = 0; i < ordered.length; i++) {
      idOf[ordered[i].key] = 'e${i + 1}';
    }

    final evidenceJson = <J>[];
    for (final e in ordered) {
      evidenceJson.add({
        'id': idOf[e.key],
        'type': e.type,
        'title': e.title,
        'content': e.content,
        'public': e.public,
        if (e.scene.isNotEmpty) 'scene': e.scene,
        if (e.caption.isNotEmpty) 'caption': e.caption,
        if (e.print != null) 'print': e.print,
      });
    }

    // ---- sim: actors ---------------------------------------------------------
    final actors = <String, dynamic>{};
    final alibiClaimTpl = ['از {a} تا {b} در {z} بودم و تا آخر شب هم همان‌جا ماندم.', 'آن بازه در {z} مشغول کار بودم؛ از حدود {a}.'];
    final relTpl0 = [
      'با $vShort چند سال همکار بودم. آدم سخت‌گیری بود ولی منصف.',
      '$vShort را از سال‌ها پیش می‌شناختم؛ رابطه‌مان کاملاً کاری بود.',
      'من و $vShort هر روز همدیگر را می‌دیدیم؛ همین.',
    ];
    final fricTxt = frictionReason[cat]!;

    for (final p in people) {
      final a = <String, dynamic>{};
      a['voice'] = voices[r.nextInt(voices.length)];
      a['nerve'] = p.culprit ? 0.4 + r.nextDouble() * 0.4 : 0.2 + r.nextDouble() * 0.7;
      a['pride'] = r.nextDouble();
      a['guilty'] = p.culprit;

      // alibi
      final tz = '${_hm(tA)}';
      if (p.culprit) {
        a['alibi'] = {
          'claim': 'از ${_hm(tA)} تا ${_hm(tD)} در ${p.claimZone} بودم و چند نفر هم مرا دیدند.',
          'short': 'همان‌طور که گفتم، ${p.claimZone}.',
          'drift': 'شاید ساعت‌ها را دقیق نگفتم… بین ${_hm(tc - 20)} و ${_hm(tc + 15)} برای چند دقیقه از آنجا بیرون رفتم؛ ولی برگشتم.',
          'lie': true,
        };
      } else if (p.liar) {
        final sk = secretKinds[p.secretKind]!;
        a['alibi'] = {
          'claim': 'آن بازه در ${p.claimZone} بودم؛ سرم شلوغ بود.',
          'short': 'گفتم که؛ ${p.claimZone}.',
          'drift': 'خب… شاید نیم‌ساعتی بیرون رفته بودم، ولی برای کار شخصی.',
          'truth': 'آن بازه در واقع در ${p.zone} بودم؛ ${sk[0]}.',
          'lie': true,
        };
        a['secret'] = {
          'reveal': 'باشه… آن شب در ${p.zone} بودم؛ ${sk[0]}. ربطی به $vShort نداشت.',
          'shame': double.parse(sk[3]),
        };
      } else {
        final tpl = alibiClaimTpl[r.nextInt(alibiClaimTpl.length)];
        a['alibi'] = {
          'claim': _f(tpl, {'a': tz, 'b': _hm(tD), 'z': p.zone}),
          'short': 'من آن موقع در ${p.zone} بودم.',
          'lie': false,
        };
      }

      // relation
      final relLines = <String>[relTpl0[r.nextInt(relTpl0.length)]];
      if (p.friction) {
        relLines.add('راستش گاهی اختلاف داشتیم؛ ${fricTxt[r.nextInt(fricTxt.length)]}. ولی اختلاف که دلیل نمی‌شود.');
      } else {
        relLines.add('همه‌چیز عادی بود؛ گاهی بحث کاری داشتیم، مثل هر جای دیگر.');
      }
      if (p.liar) {
        relLines.add('آن روزها فشار روحی داشتم؛ ولی ربطی به $vShort نداشت.');
      } else if (p.culprit) {
        relLines.add('نمی‌دانم چرا همه فکر می‌کنند کسی از او کینه داشته… من که نداشتم.');
      } else {
        relLines.add('نمی‌دانم کسی آن‌قدر از او متنفر بوده که چنین کاری بکند. نه، باورم نمی‌شود.');
      }
      a['rel'] = relLines;

      // money / pressure in life
      final moneyLines = <String>[];
      if (p.friction) {
        moneyLines.add('وضع مالی‌ام تعریفی ندارد، ولی این‌ها به این ماجرا ربطی ندارد.');
        moneyLines.add('باشه… چند ماه است قسط‌هایم عقب افتاده؛ ولی برای این کار دست به چنین کاری نمی‌زنم!');
      } else if (p.culprit) {
        moneyLines.add('مشکل مالی؟ نه؛ زندگی‌ام روال عادی دارد.');
        moneyLines.add('گفتم که؛ هیچ مشکلی ندارم.');
      } else {
        moneyLines.add('مشکل مالی خاصی ندارم؛ زندگی‌ام روال عادی دارد.');
      }
      a['money'] = moneyLines;

      // what they saw
      final saw = <String>[];
      if (p.culprit) {
        saw.add('من آن بازه جای دیگری بودم؛ چیزی ندیدم.');
        saw.add('گفتم که… چیزی ندیدم و چیزی نمی‌دانم.');
      } else {
        saw.add('آن شب سرم شلوغ بود؛ چیز خاصی ندیدم و فقط صدای رفت‌وآمد می‌آمد.');
        if (p == hearer) {
          saw.add('حدود ساعت ${_hm(tIn)} صدای باز و بسته‌شدن ${scn.entry} را شنیدم؛ کسی داشت می‌رفت یا می‌آمد.');
        } else if (p == qPerson) {
          saw.add('من ساعت ${_hm(tQ1)} برای $errand آمدم و ساعت ${_hm(tQ2)} رفتم؛ بعدش دیگر آنجا نبودم.');
        } else {
          saw.add('فقط یادم هست در ${p.zone} بودم و کسی را نزدیک ${scn.entry} نمی‌دیدم.');
        }
      }
      a['saw'] = saw;

      // what they say about the others
      final others = <String, dynamic>{};
      for (final q in people) {
        if (q == p) continue;
        String text;
        var ok = true;
        if (p.culprit && q.liar) {
          text = '${q.first} آن شب رفتار عجیبی داشت؛ چند بار گوشی‌اش را نگاه کرد و بیرون رفت. من جای شما بودم از او می‌پرسیدم.';
          ok = false;
        } else if (p.culprit && q.friction) {
          text = '${q.first} با $vShort اختلاف داشت؛ همه می‌دانستند. من جای شما بودم از او می‌پرسیدم.';
          ok = false;
        } else if (q.liar) {
          text = '${q.first} آن شب رفتار عجیبی داشت؛ چند بار گوشی‌اش را نگاه کرد و بدون توضیح بیرون رفت.';
        } else if (q.friction) {
          text = '${q.first} و $vShort اختلاف داشتند؛ چند وقت پیش بحثشان بالا گرفت.';
        } else if (q == qPerson && p == hearer) {
          text = '${q.first} زودتر از بقیه رفت؛ فکر کنم ساعت ${_hm(tQ2)} بود.';
        } else {
          final neutral = [
            '${q.first} آدم قابل‌اعتمادی است؛ چیز غیرعادی‌ای ندیدم.',
            '${q.first}؟ همکار خوبی است؛ چیزی ندارم بگویم.',
            'با ${q.first} کاری نداشتم؛ فقط آنجا بود.',
          ];
          text = neutral[r.nextInt(neutral.length)];
        }
        others[q.id] = {'text': text, 'honest': ok};
      }
      a['others'] = others;

      // reactions to evidence
      final react = <String, dynamic>{};
      if (p.culprit) {
        react[idOf['log']!] = {
          'k': 'refute', 'w': 1.0,
          'excuse': 'کارتم هفته‌هاست مشکل دارد؛ هر کسی می‌توانسته از آن استفاده کند.',
        };
        react[idOf['pItem']!] = {
          'k': 'refute', 'w': qMain == 'clear' ? 1.0 : 0.8,
          'excuse': 'طبیعی است اثر انگشتم آنجا باشد؛ همیشه با ${scn.item} سروکار داشتم.',
        };
        react[idOf['motive']!] = {
          'k': 'refute', 'w': 0.7,
          'excuse': 'این فقط یک سند قدیمی است؛ هر کس جای من بود همین را داشت.',
        };
        react[idOf['claim']!] = {
          'k': 'refute', 'w': 1.0,
          'excuse': 'حتماً اشتباهی رخ داده؛ من همان‌جا بودم، شاید کسی مرا ندیده.',
        };
        react[idOf['photoEntry']!] = {
          'k': 'refute', 'w': 0.5,
          'excuse': 'آن لباس را نیمی از اهالی اینجا دارند؛ چهره‌ای هم معلوم نیست.',
        };
        a['breakAdmit'] =
            'باشه… آن شب سری به ${scn.scene} زدم. ولی وقتی رسیدم همه‌چیز همین‌طور بود؛ من کاری نکردم!';
        a['confess'] =
            'بله… من بودم. ${motiveConfession(cat, mt[0])} نمی‌خواستم کار به اینجا برسد، ولی دیگر نمی‌توانم انکار کنم.';
      }
      if (p.liar) {
        final key = secretKeys[p.id]!;
        react[idOf[key]!] = {
          'k': 'secret',
          'deny': const [
            'این مدرک ربطی به من ندارد.',
            'نمی‌دانم از کجا آورده‌اید؛ اشتباه گرفته‌اید.',
            '…ترجیح می‌دهم بدون توضیح بگذرم.',
          ][r.nextInt(3)],
        };
      }
      if (p == qPerson) {
        react[idOf['log']!] = {
          'k': 'explain',
          'line': 'بله، ورود و خروج ساعت ${_hm(tQ1)} و ${_hm(tQ2)} مال من است؛ برای $errand بود و ربطی به ساعت اصلی ندارد.',
        };
        react[idOf['pDoor']!] = {
          'k': 'explain',
          'line': 'دستگیرهٔ ${scn.entry} را هر روز لمس می‌کنم؛ طبیعی است اثرم آنجا باشد.',
        };
      }
      if (p.friction) {
        react[idOf[fricKeys[p.id]!]!] = {
          'k': 'explain',
          'line': 'بله، اختلاف داشتیم؛ اما اختلاف که جنایت نمی‌شود!',
        };
      }
      if (clearKeys.containsKey(p.id)) {
        react[idOf[clearKeys[p.id]!]!] = {
          'k': 'explain',
          'line': 'درست است؛ همان موقع آنجا بودم و دیگران هم می‌توانند تأیید کنند.',
        };
      }
      a['react'] = react;
      actors[p.id] = a;
    }

    // ---- witnesses -----------------------------------------------------------
    final witnessList = <J>[];
    final wRoles = cat == 'murder'
        ? ['نگهبان شب', 'نظافتچی', 'همسایهٔ ساختمان مجاور']
        : (cat == 'theft' ? ['نگهبان شب', 'راننده تاکسی مقابل ساختمان', 'نظافتچی'] : ['نگهبان شب', 'کارمند شیفت شب ساختمان مجاور', 'نظافتچی']);
    final wRolePick = [...wRoles]..shuffle(r);
    for (var i = 0; i < nWit; i++) {
      final id = 'w${i + 1}';
      final first = nextFirst();
      final last = nextLast();
      final role = wRolePick[i];
      witnessList.add({
        'id': id,
        'name': '$first $last',
        'role': role,
        'bio': '$role؛ آن شب نزدیک ${scn.entry} حضور داشت.',
      });
      final wa = <String, dynamic>{
        'kind': 'witness',
        'voice': voices[r.nextInt(voices.length)],
        'nerve': 0.3 + r.nextDouble() * 0.4,
        'eager': true,
      };
      if (i == 0) {
        wa['saw'] = [
          'حدود ساعت ${_hm(tIn)} کسی با ${culprit.outfit} از کنار ${scn.entry} رد شد؛ فکر کردم کارمند است.',
          'چهره‌اش را ندیدم، اما قدش ${culprit.height} بود و عجله داشت.',
          'و فکر می‌کنم حدود ساعت ${_hm(tOut)} همان آدم با قدم‌های تند برگشت.',
        ];
      } else {
        final wrong = decoyO.outfit;
        wa['saw'] = [
          'یک نفر نزدیک ${scn.entry} بود؛ شاید با $wrong… البته تاریک بود و مطمئن نیستم.',
          'ساعتش را هم دقیق نمی‌دانم؛ شاید ${_hm(tc - 25)} بود، شاید ${_hm(tc + 20)}.',
        ];
      }
      wa['rel'] = [
        'من با $victim فقط در حد سلام و علیک آشنا بودم؛ شب‌ها او را می‌دیدم که دیر می‌رفت.',
        'همین‌قدر که می‌دانم تنها نبود؛ همیشه یک نفر با او کار می‌کرد.',
      ];
      final wo = <String, dynamic>{};
      for (final q in people) {
        String t;
        if (i == 0 && q == qPerson) {
          t = '${q.first} را دیدم؛ ساعت ${_hm(tQ1)} آمد و ساعت ${_hm(tQ2)} رفت.';
        } else if (i == 0 && q == hearer) {
          t = '${q.first} را بعد از پیدا شدن ماجرا دیدم که داشت وارد می‌شد.';
        } else {
          t = 'آن شب ${q.first} را از نزدیک ندیدم؛ نمی‌توانم چیزی بگویم.';
        }
        wo[q.id] = {'text': t, 'honest': true};
      }
      wa['others'] = wo;
      actors[id] = wa;
    }

    // ---- solution & wrap-up -------------------------------------------------
    final liarNames = liars.map((p) => p.first).join(' و ');
    final fricNames = people.where((p) => p.friction).map((p) => p.first).join(' و ');
    final explanation =
        '${culprit.full} ${motiveSentence(cat, mt[0])} کارت او ساعت ${_hm(tIn)} در ${scn.entry} ثبت شد و ساعت ${_hm(tOut)} خارج شد؛ اما ادعا کرد در ${culprit.claimZone} بوده و گزارش بررسی ادعا این را رد می‌کند. اثر انگشت او روی ${scn.item} پیدا شد و سند انگیزه («${mt[1]}») هم به او می‌رسد. '
        '${liars.isEmpty ? '' : '$liarNames برای پنهان‌کردن موضوعی شخصی دروغ گفتند اما در زمان رویداد جای دیگری بودند. '}'
        '${fricNames.isEmpty ? '' : 'اختلاف‌های $fricNames و ورود زودهنگام ${qPerson.first} مسیرهای فرعی بودند.'}';

    final suspectsJson = [
      for (final p in people)
        {
          'id': p.id,
          'name': p.full,
          'role': p.role,
          'bio': '${p.role}. ${p.bio}. ${p.height} و معمولاً با ${p.outfit} دیده می‌شود.',
        }
    ];

    final allMotives = [
      for (var i = 0; i < motives.length; i++) {'id': 'm${i + 1}', 'text': motives[i][0]}
    ];

    final fingersOut = <String, dynamic>{...fingers};
    final printsOut = <String, dynamic>{
      for (final e in printOwners.entries) idOf[e.key]!: {'owner': e.value}
    };

    final title = _f(scn.titles[r.nextInt(scn.titles.length)], slots);
    final brief = cat == 'murder'
        ? 'ساعت ${_hm(tFound)}، $victim (${scn.victimRole} $place) در ${scn.scene} بی‌جان پیدا شد. $meansTxt. ${fa(nSus)} نفر آن شب به $place مرتبط بودند. هیچ‌کس اطلاعات کامل ندارد؛ مدارک را به اشتراک بگذارید، متهمان و شاهدان را بازجویی کنید، اثر انگشت‌ها را بسنجید و قاتل را مشخص کنید. فقط یک فرصت دارید.'
        : (cat == 'theft'
            ? 'ساعت ${_hm(tFound)} مشخص شد ${scn.object} از ${scn.scene} $place ناپدید شده است. ${fa(nSus)} نفر آن شب به آنجا دسترسی داشتند. هیچ‌کس اطلاعات کامل ندارد؛ مدارک را به اشتراک بگذارید، متهمان و شاهدان را بازجویی کنید، اثر انگشت‌ها را بسنجید و دزد را مشخص کنید. فقط یک فرصت دارید.'
            : 'ساعت ${_hm(tFound)} سامانهٔ امنیتی $place نشت اطلاعات را ثبت کرد: ${scn.object} روی یک حافظهٔ خارجی کپی شده است. ${fa(nSus)} نفر دسترسی داشتند. هیچ‌کس اطلاعات کامل ندارد؛ مدارک را به اشتراک بگذارید، متهمان و شاهدان را بازجویی کنید، اثر انگشت‌ها را بسنجید و جاسوس را مشخص کنید. فقط یک فرصت دارید.');

    return {
      'id': 'gen_$sd',
      'generated': true,
      'seed': sd,
      'title': title,
      'category': cat,
      'difficulty': diff,
      'minPlayers': 1,
      'maxPlayers': 6,
      'brief': brief,
      'roles': [
        for (final x in playerRoles[cat]!) {'name': x[0], 'desc': x[1]}
      ],
      'suspects': suspectsJson,
      'witnesses': witnessList,
      'motives': allMotives,
      'evidence': evidenceJson,
      'solution': {
        'culprit': culprit.id,
        'motive': 'm${culMotive + 1}',
        'keyEvidence': [idOf['log'], idOf['pItem'], idOf['motive'], idOf['claim']],
        'explanation': explanation,
      },
      'sim': {
        'actors': actors,
        'fingers': fingersOut,
        'prints': printsOut,
        'lab': diff == 'easy' ? 5 : (diff == 'hard' ? 3 : 4),
      },
    };
  }

  static const difficulties = ['easy', 'standard', 'hard'];

  /// Structural promises every playable case must keep. Returns null when the
  /// case is fine, otherwise a short reason.
  static String? validate(J c, {int players = 1}) {
    final ev = asList(c['evidence']);
    final ids = ev.map((e) => '${e['id']}').toSet();
    final sol = Map<String, dynamic>.from(c['solution'] as Map);
    final keys = ((sol['keyEvidence'] as List?) ?? const []).map((e) => '$e').toList();
    if (keys.isEmpty) return 'no key evidence';
    if (!ids.containsAll(keys)) return 'key evidence is missing';
    final sus = asList(c['suspects']).map((e) => '${e['id']}').toSet();
    if (!sus.contains('${sol['culprit']}')) return 'culprit is not a suspect';
    final mot = asList(c['motives']).map((e) => '${e['id']}').toSet();
    if (!mot.contains('${sol['motive']}')) return 'motive is not listed';
    if (!ev.any((e) => e['type'] == 'print')) return 'no fingerprint evidence';
    final need = players < 3 ? players : 3;
    if (ev.where((e) => e['public'] != true).length < need) return 'not enough private evidence';
    return null;
  }

  /// The detective bot: builds a fresh case, checks it, and quietly builds
  /// another one with a new seed if the check fails. [difficulty] may be
  /// `auto`, which mixes easy, standard and hard cases.
  static J generateChecked({String category = 'random', String difficulty = 'auto', int players = 1, int? seed}) {
    final r = Random(seed ?? Random.secure().nextInt(0x7ffffff0));
    J? last;
    for (var i = 0; i < 8; i++) {
      final diff = difficulty == 'auto' ? const ['easy', 'standard', 'standard', 'hard'][r.nextInt(4)] : difficulty;
      final c = generate(category: category, difficulty: diff, seed: r.nextInt(0x7ffffff0));
      if (validate(c, players: players) == null) return c;
      last = c;
    }
    return last!;
  }

  static String motiveSentence(String cat, String motive) {
    if (cat == 'murder') return 'به‌دلیل «$motive» قاتل ماجرا بود.';
    if (cat == 'theft') return 'به‌دلیل «$motive» دزد ماجرا بود.';
    return 'به‌دلیل «$motive» جاسوس ماجرا بود.';
  }

  static String motiveConfession(String cat, String motive) {
    return 'دلیلش «$motive» بود.';
  }
}
