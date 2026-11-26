import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'util.dart';

class Rank {
  const Rank(this.idx, this.name, this.min);
  final int idx;
  final String name;
  final int min;
}

const ranks = [
  Rank(0, 'مأمور تازه‌کار', 0),
  Rank(1, 'مأمور میدانی', 2),
  Rank(2, 'کارآگاه ارشد', 5),
  Rank(3, 'رئیس واحد', 10),
];

class Store extends ChangeNotifier {
  Store._();
  static final Store i = Store._();

  late SharedPreferences _p;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    await _ensureIds();
  }

  Future<void> _ensureIds() async {
    if (_p.getString('pid') == null) await _p.setString('pid', randId(12));
    if (_p.getString('agent') == null) await _p.setString('agent', newAgentCode());
  }

  String get pid => _p.getString('pid')!;
  String get agent => _p.getString('agent')!;
  String get codename => _p.getString('codename') ?? '';
  int get wins => _p.getInt('wins') ?? 0;
  int get played => _p.getInt('played') ?? 0;
  List<String> get solved => _p.getStringList('solved') ?? [];

  /// Closed cases are final: id -> 'won' or 'lost'. They can never be replayed.
  Map<String, String> get closed {
    final out = <String, String>{};
    for (final e in _p.getStringList('closed') ?? const <String>[]) {
      final i = e.lastIndexOf(':');
      if (i > 0) out[e.substring(0, i)] = e.substring(i + 1);
    }
    return out;
  }

  int get streak => _p.getInt('streak') ?? 0;
  int get bestStreak => _p.getInt('bestStreak') ?? 0;
  int get lost => closed.values.where((v) => v == 'lost').length;
  bool get particles => _p.getBool('particles') ?? true;
  bool get scanline => _p.getBool('scanline') ?? true;
  bool get glitch => _p.getBool('glitch') ?? true;
  bool get largeFont => _p.getBool('largeFont') ?? false;
  bool get saver => _p.getBool('saver') ?? false;
  bool get haptics => _p.getBool('haptics') ?? true;
  bool get sound => _p.getBool('sound') ?? true;
  bool get guideSeen => _p.getBool('guideSeen') ?? false;
  String get relayUrl => _p.getString('relayUrl') ?? '';
  int get quality => _p.getInt('quality') ?? 1;

  // Rank is cosmetic: it follows the number of solved cases and unlocks nothing.
  Rank get rank => ranks.lastWhere((r) => solved.length >= r.min);
  Rank? get nextRank {
    for (final r in ranks) {
      if (r.min > solved.length) return r;
    }
    return null;
  }

  /// Private per-case notebook. Deliberately does not notify listeners: the
  /// whole app listens to the store and typing must not rebuild it.
  String noteFor(String caseId) => _p.getString('note_$caseId') ?? '';

  Future<void> setNote(String caseId, String text) async {
    if (text.trim().isEmpty) {
      await _p.remove('note_$caseId');
    } else {
      await _p.setString('note_$caseId', text);
    }
  }

  int get winRatePct => winRatePercent(played, wins);

  int get particleCount {
    final base = [20, 40, 60][quality.clamp(0, 2)];
    return saver ? base ~/ 2 : base;
  }

  Future<void> put(String k, Object v) async {
    if (v is bool) {
      await _p.setBool(k, v);
    } else if (v is int) {
      await _p.setInt(k, v);
    } else if (v is String) {
      await _p.setString(k, v);
    } else if (v is List<String>) {
      await _p.setStringList(k, v);
    }
    notifyListeners();
  }

  Future<bool> addResult({required bool won, required String caseId}) async {
    final before = rank.idx;
    final c = closed;
    if (c.containsKey(caseId)) return false; // a closed case counts once
    c[caseId] = won ? 'won' : 'lost';
    await _p.setStringList('closed', [for (final e in c.entries) '${e.key}:${e.value}']);
    await _p.setInt('played', played + 1);
    final st = won ? streak + 1 : 0;
    await _p.setInt('streak', st);
    if (st > bestStreak) await _p.setInt('bestStreak', st);
    if (won) {
      await _p.setInt('wins', wins + 1);
      await _p.setStringList('solved', [...solved, caseId]);
    }
    notifyListeners();
    return rank.idx > before;
  }

  Map<String, dynamic>? get session {
    final s = _p.getString('session');
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(Map<String, dynamic> s) async {
    await _p.setString('session', jsonEncode(s));
    notifyListeners();
  }

  Future<void> clearSession() async {
    await _p.remove('session');
    notifyListeners();
  }

  Future<void> wipe() async {
    await _p.clear();
    await _ensureIds();
    notifyListeners();
  }
}
