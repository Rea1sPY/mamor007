import '../core/util.dart';

/// Debrief of one hypothesis. There are no points: the case is won or lost
/// by the team verdict only.
J gradeHypothesis(J hyp, J solution) {
  final key = (solution['keyEvidence'] as List).map((e) => '$e').toSet();
  final sel = ((hyp['evidence'] as List?) ?? const []).map((e) => '$e').toSet();
  return {
    'culprit': hyp['suspect'] == solution['culprit'],
    'motive': hyp['motive'] == solution['motive'],
    'evidenceHit': key.intersection(sel).length,
    'evidenceTotal': key.length,
  };
}

/// Team verdict: the suspect with the most votes. Ties go to the suspect named
/// by more hypotheses, then to the earliest hypothesis. Null when nothing was filed.
String? pickVerdict(List<J> hyps, Map<String, int> votesByPid) {
  if (hyps.isEmpty) return null;
  final votes = <String, int>{};
  final named = <String, int>{};
  final firstSeen = <String, int>{};
  for (var i = 0; i < hyps.length; i++) {
    final s = '${hyps[i]['suspect']}';
    votes[s] = (votes[s] ?? 0) + (votesByPid['${hyps[i]['pid']}'] ?? 0);
    named[s] = (named[s] ?? 0) + 1;
    firstSeen.putIfAbsent(s, () => i);
  }
  final ids = votes.keys.toList();
  ids.sort((a, b) {
    final v = votes[b]!.compareTo(votes[a]!);
    if (v != 0) return v;
    final n = named[b]!.compareTo(named[a]!);
    if (n != 0) return n;
    return firstSeen[a]!.compareTo(firstSeen[b]!);
  });
  return ids.first;
}
