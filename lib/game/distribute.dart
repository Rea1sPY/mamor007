import 'dart:math';

import '../core/util.dart';

Map<String, List<String>> distributeEvidence(List<String> pids, List<J> evidence, Random rnd) {
  final order = [...pids]..shuffle(rnd);
  final out = {for (final p in pids) p: <String>[]};
  final priv = <String>[];
  for (final e in evidence) {
    if (e['public'] == true) {
      for (final p in pids) {
        out[p]!.add(e['id'] as String);
      }
    } else {
      priv.add(e['id'] as String);
    }
  }
  for (var i = 0; i < priv.length; i++) {
    out[order[i % order.length]]!.add(priv[i]);
  }
  return out;
}
