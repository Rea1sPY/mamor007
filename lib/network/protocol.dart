import 'dart:convert';

import '../core/util.dart';

enum Phase { lobby, briefing, investigation, hypothesis, voting, result }

Phase phaseOf(String s) =>
    Phase.values.firstWhere((p) => p.name == s, orElse: () => Phase.lobby);

class Msg {
  const Msg(this.type, this.from, this.seq, this.data);
  final String type;
  final String from;
  final int seq;
  final Map<String, dynamic> data;

  String encode(String key) {
    final body = jsonEncode({'t': type, 'f': from, 's': seq, 'd': data});
    return jsonEncode({'b': body, 'g': hmac(key, body)});
  }

  static Msg? decode(String raw, String key) {
    try {
      final o = jsonDecode(raw) as Map<String, dynamic>;
      final body = o['b'] as String;
      if (!constEq(hmac(key, body), o['g'] as String)) return null;
      final b = jsonDecode(body) as Map<String, dynamic>;
      return Msg(
        b['t'] as String,
        b['f'] as String,
        (b['s'] as num).toInt(),
        Map<String, dynamic>.from(b['d'] as Map),
      );
    } catch (_) {
      return null;
    }
  }
}
