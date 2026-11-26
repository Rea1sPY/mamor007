import 'dart:math';

import '../core/util.dart';
import 'case_model.dart';
import 'voice.dart';

/// One answer from a suspect or witness.
class Reply {
  const Reply(
    this.text, {
    this.obs = const [],
    this.stage = 0,
    this.flag = '',
    this.lawyer = false,
    this.ok = true,
  });

  final String text;
  final List<String> obs;
  final int stage;

  /// drift, secret, break, confess, lawyer, sample, refuse, dup
  final String flag;
  final bool lawyer;
  final bool ok;

  J toJson() => {'text': text, 'obs': obs, 'stage': stage, 'flag': flag, 'lawyer': lawyer, 'ok': ok};
}

class _St {
  double stress = 0;
  double trust = 0;
  final Map<String, int> count = {};
  final Set<String> shown = {};
  final Set<String> refuted = {};
  double refuteScore = 0;
  bool secretOut = false;
  bool drifted = false;
  bool breakDone = false;
  bool confessed = false;
  bool lawyer = false;
  bool sampleTaken = false;
  int sampleRefusals = 0;
  int relLevel = 0;
  int moneyLevel = 0;
  int sawLevel = 0;
  final List<String> recent = [];
}

class _Actor {
  _Actor(this.id, this.name, this.j, this.witness);

  final String id;
  final String name;
  final J j;
  final bool witness;

  String get voice {
    final v = '${j['voice']}';
    return voices.contains(v) ? v : 'calm';
  }

  double n(String k, double d) => (j[k] as num?)?.toDouble() ?? d;
  bool get guilty => j['guilty'] == true;
  String str(String k) => '${j[k] ?? ''}';

  List<String> list(String k) {
    final v = j[k];
    if (v is! List) return const [];
    return v.map((e) => '$e').toList();
  }

  J? map(String k) {
    final v = j[k];
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }
}

/// Builds actor definitions for hand-written cases that have no `sim.actors`.
Map<String, J> legacyActors(CaseData cs) {
  final out = <String, J>{};
  final culprit = '${cs.solution['culprit']}';
  final keys = (cs.solution['keyEvidence'] as List).map((e) => '$e').toList();
  for (final s in cs.suspects) {
    final id = '${s['id']}';
    final name = '${s['name']}';
    final resp = Map<String, dynamic>.from((s['responses'] as Map?) ?? const {});
    final h = seedOf(id);
    final guilty = id == culprit;
    final react = <String, dynamic>{};
    if (guilty) {
      for (final k in keys) {
        react[k] = {
          'k': 'refute',
          'w': 1.0,
          'excuse': const [
            'این مدرک چیزی را ثابت نمی‌کند.',
            'کسی می‌تواند آن را جعل کرده باشد.',
            'توضیح دارم، ولی اینجا وقتش نیست.',
          ][h % 3],
        };
      }
    }
    out[id] = {
      'voice': voices[h % voices.length],
      'nerve': 0.4 + (h % 5) * 0.09,
      'pride': 0.3 + (h % 3) * 0.2,
      'guilty': guilty,
      'accuse': '${resp['accuse'] ?? ''}',
      'alibi': {
        'claim': '${resp['pressure'] ?? 'آن شب سر کار خودم بودم.'}',
        'short': '${resp['pressure'] ?? 'همان که گفتم.'}',
        'lie': guilty,
        if (guilty) 'drift': 'شاید ساعت‌ها را دقیق نگفتم؛ ولی هر چه بود، من کاری نکردم.',
      },
      'rel': ['${resp['empathy'] ?? 'رابطهٔ ما کاری بود.'}', 'کار ما در حد همکاری معمولی بود؛ بیشتر از این چیزی نیست.'],
      'money': generalMoney,
      'saw': ['آن شب چیز مشکوکی ندیدم.', 'فقط رفت‌وآمدهای معمول؛ چیز خاصی یادم نمی‌آید.'],
      'others': <String, dynamic>{},
      'react': react,
      if (guilty) 'breakAdmit': 'باشه… آن‌جا بودم. ولی نمی‌خواستم کار به اینجا برسد.',
      if (guilty) 'confess': 'بله… من این کار را کردم. دیگر نمی‌توانم ادامه بدهم.',
    };
  }
  return out;
}

class Interrogator {
  Interrogator(this.cs, this.rnd) {
    final sim = cs.sim;
    final raw = sim['actors'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final id = '$k';
        final j = Map<String, dynamic>.from(v as Map);
        final isW = j['kind'] == 'witness';
        final name = isW ? _nameOf(cs.witnesses, id) : _nameOf(cs.suspects, id);
        _a[id] = _Actor(id, name, j, isW);
      });
    } else {
      legacyActors(cs).forEach((id, j) {
        _a[id] = _Actor(id, _nameOf(cs.suspects, id), j, false);
      });
    }
    switch (cs.difficulty) {
      case 'easy':
        _dm = 1.15;
        _need = 2.0;
        _tellP = 1.0;
        _lawyerBonus = 1.5;
      case 'hard':
        _dm = 0.85;
        _need = 3.0;
        _tellP = 0.55;
        _lawyerBonus = 0.0;
      default:
        _dm = 1.0;
        _need = 2.5;
        _tellP = 0.8;
        _lawyerBonus = 0.5;
    }
  }

  final CaseData cs;
  final Random rnd;
  final Map<String, _Actor> _a = {};
  final Map<String, _St> _s = {};
  double _dm = 1.0;
  double _need = 2.5;
  double _tellP = 0.8;
  double _lawyerBonus = 0.5;

  static String _nameOf(List<J> list, String id) {
    for (final e in list) {
      if (e['id'] == id) return '${e['name']}';
    }
    return id;
  }

  bool has(String id) => _a.containsKey(id);
  bool isWitness(String id) => _a[id]?.witness ?? false;
  bool sampleTaken(String id) => _s[id]?.sampleTaken ?? false;
  bool lawyered(String id) => _s[id]?.lawyer ?? false;

  _St _st(String id) => _s.putIfAbsent(id, () => _St());

  int _stage(double s) => s < 2.5 ? 0 : (s < 5 ? 1 : (s < 7.5 ? 2 : 3));

  double _lawyerAt(_Actor a) {
    final custom = a.j['lawyerAt'];
    if (custom is num) return custom.toDouble() + _lawyerBonus;
    return 7.0 + a.n('pride', 0.4) * 2.2 + _lawyerBonus;
  }

  String _pickNS(List<String> l) => l[rnd.nextInt(l.length)];

  String _pick(List<String> l, _St st) {
    if (l.isEmpty) return '';
    final fresh = l.where((e) => !st.recent.contains(e)).toList();
    final src = fresh.isEmpty ? l : fresh;
    final r = src[rnd.nextInt(src.length)];
    st.recent.add(r);
    if (st.recent.length > 14) st.recent.removeAt(0);
    return r;
  }

  String _say(_Actor a, _St st, String core,
      {String tone = 'neutral', bool repeat = false, bool lead = true}) {
    final v = a.voice;
    final parts = <String>[];
    if (tone != 'neutral') {
      final tl = toneLead[tone]?[v];
      if (tl != null && rnd.nextDouble() < 0.8) parts.add(_pick(tl, st));
    }
    if (repeat) {
      parts.add(_pick(repeatLead[v]!, st));
    } else if (lead && rnd.nextDouble() < 0.7) {
      parts.add(_pick(openers[v]!, st));
    }
    parts.add(core);
    if (rnd.nextDouble() < 0.25) parts.add(_pick(closers[v]!, st));
    return parts.join(' ');
  }

  List<String> _obs(_Actor a, _St st, {bool lying = false, bool hiding = false}) {
    final out = <String>[];
    final stage = _stage(st.stress);
    if (stage >= 1 && rnd.nextDouble() < 0.75) {
      out.add(_pick(stage == 1 ? cueStage1 : (stage == 2 ? cueStage2 : cueStage3), st));
    }
    if (lying) {
      if (rnd.nextDouble() < 0.6 * _tellP) out.add(_pick(cueLie, st));
    } else if (hiding) {
      if (rnd.nextDouble() < 0.5 * _tellP) out.add(_pick(cueHide, st));
    } else if (rnd.nextDouble() < 0.06) {
      out.add(_pick(cueLie, st)); // honest people sometimes look shifty too
    } else if (stage == 0 && rnd.nextDouble() < 0.18) {
      out.add(_pick(cueNoise, st));
    }
    if (out.length > 2) out.removeRange(2, out.length);
    return out;
  }

  Reply _reply(
    _Actor a,
    _St st,
    String core, {
    String tone = 'neutral',
    String flag = '',
    bool lying = false,
    bool hiding = false,
    bool repeat = false,
    bool lead = true,
  }) =>
      Reply(
        _say(a, st, core, tone: tone, repeat: repeat, lead: lead),
        obs: _obs(a, st, lying: lying, hiding: hiding),
        stage: _stage(st.stress),
        flag: flag,
      );

  void _applyTone(_Actor a, _St st, String tone, String topic) {
    final k = a.n('nerve', 0.5) + 0.5;
    switch (tone) {
      case 'pressure':
        st.stress += 1.1 * k * _dm;
        st.trust = max(0.0, st.trust - 0.4);
      case 'accuse':
        st.stress += 1.6 * k * _dm;
        st.trust = max(0.0, st.trust - 0.8);
      case 'empathy':
        st.stress = max(0.0, st.stress - 0.9);
        st.trust += 1.0;
      default:
        st.stress += (a.guilty && topic == 'alibi') ? 0.4 * k : 0.1;
        st.trust += 0.1;
    }
  }

  bool _opens(_St st, J sec, String tone) {
    final shame = double.tryParse('${sec['shame']}') ?? 0.6;
    final hot = tone == 'pressure' || tone == 'accuse';
    return st.trust >= 1 + shame * 3 || (hot && st.stress >= 5.5 + shame * 1.5);
  }

  /// Main entry. [topic]: alibi, rel, money, saw, others, evidence.
  Reply ask(String sid, String topic, String tone, String arg) {
    final a = _a[sid];
    if (a == null) return const Reply('…', ok: false);
    final st = _st(sid);
    if (st.lawyer) {
      return Reply(_pickNS(lawyerAgain), lawyer: true, flag: 'lawyer', stage: 3);
    }
    if (st.confessed) {
      return Reply(_pickNS(afterConfess), flag: 'confess', stage: _stage(st.stress));
    }
    final t = const ['neutral', 'pressure', 'empathy', 'accuse'].contains(tone) ? tone : 'neutral';
    _applyTone(a, st, t, topic);
    final hot = t == 'pressure' || t == 'accuse';
    if (!a.witness && hot && st.stress >= _lawyerAt(a)) {
      st.lawyer = true;
      return Reply(_pickNS(lawyerFirst), lawyer: true, flag: 'lawyer', stage: 3);
    }
    Reply r;
    switch (topic) {
      case 'alibi':
        r = _alibi(a, st, t);
      case 'rel':
        r = _levels(a, st, t, 'rel');
      case 'money':
        r = _levels(a, st, t, 'money');
      case 'saw':
        r = _saw(a, st, t);
      case 'others':
        r = _others(a, st, t, arg);
      case 'evidence':
        r = _evidence(a, st, t, arg);
      default:
        r = _reply(a, st, _pick(noNew, st), tone: t);
    }
    if (!a.witness && hot && st.stress >= _lawyerAt(a) - 1.8 && !st.confessed && r.obs.length < 3) {
      return Reply(
        r.text,
        obs: [...r.obs, _pick(lawyerWarn, st)],
        stage: r.stage,
        flag: r.flag,
      );
    }
    return r;
  }

  Reply _alibi(_Actor a, _St st, String tone) {
    if (a.witness) return _reply(a, st, _pickNS(witnessNA), tone: tone);
    final al = a.map('alibi');
    final n = st.count['alibi'] ?? 0;
    st.count['alibi'] = n + 1;
    if (al == null) return _reply(a, st, 'آن شب سر کار خودم بودم.', tone: tone);
    final lie = al['lie'] == true;
    final claim = '${al['claim']}';
    final short = '${al['short'] ?? claim}';
    final truth = '${al['truth'] ?? ''}';
    final drift = '${al['drift'] ?? ''}';
    if (st.secretOut && truth.isNotEmpty) {
      return _reply(a, st, truth, tone: tone, repeat: n > 0);
    }
    if (tone == 'accuse' && a.str('accuse').isNotEmpty) {
      return _reply(a, st, a.str('accuse'), tone: tone, lying: lie, lead: false);
    }
    if (n == 0) return _reply(a, st, claim, tone: tone, lying: lie);
    if (drift.isNotEmpty && !st.drifted && (n >= 2 || st.stress >= 4.5)) {
      st.drifted = true;
      return _reply(a, st, drift, tone: tone, flag: 'drift', lying: true);
    }
    st.stress += 0.3 * a.n('nerve', 0.5) * _dm;
    return _reply(a, st, st.drifted ? drift : short, tone: tone, repeat: true, lying: lie);
  }

  Reply _levels(_Actor a, _St st, String tone, String key) {
    final list = a.list(key);
    final n = st.count[key] ?? 0;
    st.count[key] = n + 1;
    if (list.isEmpty) return _reply(a, st, _pick(key == 'money' ? generalMoney : generalOthers, st), tone: tone);
    if (!a.witness && !a.guilty) {
      final sec = a.map('secret');
      if (sec != null && !st.secretOut && _opens(st, sec, tone)) {
        st.secretOut = true;
        return _reply(a, st, '${sec['reveal']}', tone: tone, flag: 'secret');
      }
    }
    if (key == 'rel' &&
        a.guilty &&
        !st.breakDone &&
        st.trust >= 4.5 &&
        st.stress >= 3 &&
        a.str('breakAdmit').isNotEmpty) {
      st.breakDone = true;
      return _reply(a, st, a.str('breakAdmit'), tone: tone, flag: 'break', lying: true);
    }
    var lvl = key == 'rel' ? st.relLevel : st.moneyLevel;
    var advanced = false;
    if (n > 0 && lvl < list.length - 1 && (st.trust >= 1.5 || st.stress >= 2.5)) {
      lvl++;
      advanced = true;
      if (key == 'rel') {
        st.relLevel = lvl;
      } else {
        st.moneyLevel = lvl;
      }
    }
    final text = list[min(lvl, list.length - 1)];
    final hiding = !a.guilty && !a.witness && a.map('secret') != null && !st.secretOut;
    return _reply(a, st, text, tone: tone, repeat: n > 0 && !advanced, hiding: hiding);
  }

  Reply _saw(_Actor a, _St st, String tone) {
    final list = a.list('saw');
    final n = st.count['saw'] ?? 0;
    st.count['saw'] = n + 1;
    if (list.isEmpty) return _reply(a, st, _pick(noNew, st), tone: tone);
    var lvl = st.sawLevel;
    var advanced = n == 0;
    final eager = a.witness || a.j['eager'] == true;
    if (n > 0 && lvl < list.length - 1 && (eager || st.trust >= 1 || st.stress >= 2.5 || n >= 2)) {
      lvl++;
      st.sawLevel = lvl;
      advanced = true;
    }
    if (!advanced) {
      return _reply(a, st, _pick(noNew, st), tone: tone);
    }
    var text = list[min(lvl, list.length - 1)];
    if (a.witness && (tone == 'pressure' || tone == 'accuse') && st.stress >= 2) {
      text = '${_pick(witnessPressure, st)} $text';
    }
    return _reply(a, st, text, tone: tone, lying: a.guilty && !a.witness);
  }

  Reply _others(_Actor a, _St st, String tone, String arg) {
    final key = 'others:$arg';
    final n = st.count[key] ?? 0;
    st.count[key] = n + 1;
    final m = a.map('others');
    final e = m == null ? null : m[arg];
    var text = _pick(generalOthers, st);
    var honest = true;
    if (e is Map) {
      text = '${e['text']}';
      honest = e['honest'] != false;
    } else if (e is String) {
      text = e;
    }
    return _reply(a, st, text, tone: tone, repeat: n > 0, lying: !honest);
  }

  Reply _evidence(_Actor a, _St st, String tone, String eid) {
    final first = !st.shown.contains(eid);
    st.shown.add(eid);
    final rx = a.map('react')?[eid];
    final rm = rx is Map ? Map<String, dynamic>.from(rx) : null;
    if (rm == null || a.witness) {
      st.stress += 0.1;
      return _reply(a, st, _pick(noneLines, st), tone: tone);
    }
    switch ('${rm['k']}') {
      case 'refute':
        return _refute(a, st, tone, eid, rm);
      case 'secret':
        return _secret(a, st, tone, first, rm);
      case 'explain':
        return _reply(a, st, '${rm['line']}', tone: tone, repeat: !first);
      default:
        return _reply(a, st, _pick(noneLines, st), tone: tone);
    }
  }

  Reply _refute(_Actor a, _St st, String tone, String eid, J rm) {
    final w = (rm['w'] as num?)?.toDouble() ?? 1.0;
    final fresh = st.refuted.add(eid);
    if (fresh) {
      st.refuteScore += w;
      st.stress += 1.8 * w * (0.5 + a.n('nerve', 0.5)) * _dm;
    }
    final stage = _stage(st.stress);
    if (st.refuteScore >= _need && stage >= 2 && a.str('confess').isNotEmpty) {
      st.confessed = true;
      return _reply(a, st, a.str('confess'), tone: tone, flag: 'confess', lead: false);
    }
    if (st.refuteScore >= _need - 1.0 && !st.breakDone && stage >= 1 && a.str('breakAdmit').isNotEmpty) {
      st.breakDone = true;
      return _reply(a, st, a.str('breakAdmit'), tone: tone, flag: 'break', lying: true);
    }
    return _reply(a, st, '${rm['excuse']}', tone: tone, repeat: !fresh, lying: true);
  }

  Reply _secret(_Actor a, _St st, String tone, bool first, J rm) {
    final sec = a.map('secret');
    if (sec == null) return _reply(a, st, _pick(noneLines, st), tone: tone);
    if (st.secretOut) {
      return _reply(a, st, 'همان است که گفتم؛ همین بود و بیشتر نیست.', tone: tone, repeat: true);
    }
    final shame = double.tryParse('${sec['shame']}') ?? 0.6;
    if (shame <= 0.5 || st.stress >= 3 || st.trust >= 2.5 || !first) {
      st.secretOut = true;
      st.stress += 0.3;
      return _reply(a, st, '${sec['reveal']}', tone: tone, flag: 'secret');
    }
    st.stress += 1.0 * (0.5 + a.n('nerve', 0.5)) * _dm;
    return _reply(a, st, '${rm['deny']}', tone: tone, hiding: true);
  }

  /// Fingerprint sample request.
  Reply sample(String sid) {
    final a = _a[sid];
    if (a == null) return const Reply('…', ok: false);
    if (a.witness) return const Reply('نیازی به نمونه از شاهد نیست.', ok: false);
    final st = _st(sid);
    if (st.sampleTaken) {
      return Reply('نمونهٔ ${a.name} پیش‌تر گرفته شده است.', ok: false, flag: 'dup');
    }
    if (st.lawyer && cs.difficulty != 'easy') {
      return Reply(_pickNS(lawyerAgain), lawyer: true, flag: 'refuse', stage: 3);
    }
    var p = a.guilty ? 0.65 : (a.n('pride', 0.4) > 0.6 ? 0.3 : 0.06);
    if (st.stress >= 5 || st.refuted.isNotEmpty) p *= 0.3;
    if (st.trust >= 2) p *= 0.3;
    if (st.sampleRefusals >= 2) p = 0;
    if (rnd.nextDouble() < p) {
      st.sampleRefusals++;
      st.stress += 0.4;
      return Reply(_pick(sampleRefuse, st),
          flag: 'refuse', stage: _stage(st.stress), obs: _obs(a, st, hiding: true));
    }
    final forced = st.sampleRefusals >= 2;
    st.sampleTaken = true;
    return Reply(_pick(forced ? sampleForced : sampleConsent, st),
        flag: 'sample', stage: _stage(st.stress), obs: _obs(a, st, hiding: a.guilty));
  }
}
