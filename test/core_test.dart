import 'dart:math';

import 'package:case007/core/badges.dart';
import 'package:case007/core/relay_config.dart';
import 'package:case007/core/util.dart';
import 'package:case007/game/case_model.dart';
import 'package:case007/game/distribute.dart';
import 'package:case007/game/gen_data.dart';
import 'package:case007/game/generator.dart';
import 'package:case007/game/interrogation.dart';
import 'package:case007/game/prints.dart';
import 'package:case007/game/scoring.dart';
import 'package:case007/network/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void checkCase(CaseData c) {
  final ids = c.evidence.map((e) => e['id']).toSet();
  expect(ids.containsAll(c.solution['keyEvidence'] as List), isTrue, reason: c.id);
  expect(c.suspectIds.contains(c.solution['culprit']), isTrue);
  expect(c.motiveIds.contains(c.solution['motive']), isTrue);
  for (var n = 1; n <= 6; n++) {
    final pids = List.generate(n, (i) => 'p$i');
    final d = distributeEvidence(pids, c.evidence, Random(n));
    final priv = c.evidence.where((e) => e['public'] != true).map((e) => e['id']).toList();
    for (final id in priv) {
      expect(pids.where((p) => d[p]!.contains(id)).length, 1);
    }
    for (final p in pids) {
      expect(d[p]!.isNotEmpty, isTrue);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('protocol signs and verifies', () {
    final raw = const Msg('chat', 'p1', 5, {'text': 'hi'}).encode('KEY123');
    expect(Msg.decode(raw, 'KEY123')?.data['text'], 'hi');
    expect(Msg.decode(raw, 'WRONG1'), isNull);
    expect(Msg.decode(raw.replaceFirst('hi', 'ho'), 'KEY123'), isNull);
  });

  test('verdict is decided by votes, then by suspects named', () {
    final hyps = [
      {'pid': 'a', 'suspect': 's1'},
      {'pid': 'b', 'suspect': 's2'},
      {'pid': 'c', 'suspect': 's2'},
    ];
    expect(pickVerdict(hyps, {'a': 2}), 's1');
    expect(pickVerdict(hyps, {}), 's2');
    expect(pickVerdict([], {}), isNull);
    final sol = {'culprit': 's1', 'motive': 'm1', 'keyEvidence': ['e1', 'e2']};
    final g = gradeHypothesis({'suspect': 's1', 'motive': 'm2', 'evidence': ['e1']}, sol);
    expect(g['culprit'], true);
    expect(g['motive'], false);
    expect(g['evidenceHit'], 1);
  });

  test('hand-written cases load and are consistent for 1 to 6 players', () async {
    final cases = await CaseLoader.loadAll();
    expect(cases.length, 5);
    expect(cases.map((c) => c.id).toSet().length, 5);
    for (final c in cases) {
      expect(c.minPlayers, 1);
      checkCase(c);
      expect(c.hasPrints, isTrue);
    }
  });

  test('generator makes consistent, solvable cases', () {
    for (final cat in CaseGenerator.categories) {
      for (final diff in ['easy', 'standard', 'hard']) {
        for (var seed = 1; seed <= 25; seed++) {
          final c = CaseData(CaseGenerator.generate(category: cat, difficulty: diff, seed: seed));
          checkCase(c);
          expect(c.witnesses.isNotEmpty, isTrue);
          final culprit = '${c.solution['culprit']}';
          final actors = c.sim['actors'] as Map;
          final react = (actors[culprit] as Map)['react'] as Map;
          for (final k in c.solution['keyEvidence'] as List) {
            expect(react.containsKey(k), isTrue, reason: '$cat $diff $seed');
          }
          // the decisive print must belong to the culprit
          final prints = c.sim['prints'] as Map;
          final owners = prints.values.map((e) => (e as Map)['owner']).toList();
          expect(owners.contains(culprit), isTrue);
          // evidence is never leaked through public person data
          expect(CaseData.publicPerson(c.suspects.first).containsKey('guilty'), isFalse);
        }
      }
    }
  });

  test('same seed gives same case, different seeds differ', () {
    final a = CaseGenerator.generate(seed: 42, category: 'murder');
    final b = CaseGenerator.generate(seed: 42, category: 'murder');
    final c = CaseGenerator.generate(seed: 43, category: 'murder');
    expect('$a', '$b');
    expect('$a' == '$c', isFalse);
  });

  test('lab: owner matches, others do not', () {
    final r = Random(1);
    final scene = {'p': 'loop', 's': 5, 'q': 'clear'};
    expect(labCompare(scene, {'p': 'loop', 's': 5}, true, r)['verdict'], 'match');
    expect(labCompare(scene, {'p': 'loop', 's': 9}, false, r)['verdict'], 'no');
    expect(labCompare({'p': 'loop', 's': 5, 'q': 'smudged'}, {'p': 'loop', 's': 5}, true, r)['verdict'], 'unusable');
  });

  test('culprit confesses under enough evidence; repeated questions vary', () {
    for (var seed = 1; seed <= 20; seed++) {
      final c = CaseData(CaseGenerator.generate(category: 'murder', difficulty: 'standard', seed: seed));
      final it = Interrogator(c, Random(seed));
      final culprit = '${c.solution['culprit']}';
      final react = ((c.sim['actors'] as Map)[culprit] as Map)['react'] as Map;
      var confessed = false;
      for (final k in react.keys) {
        final rep = it.ask(culprit, 'evidence', 'neutral', '$k');
        if (rep.flag == 'confess') confessed = true;
      }
      expect(confessed, isTrue, reason: 'seed $seed');
      final it2 = Interrogator(c, Random(seed));
      final texts = <String>{};
      for (var i = 0; i < 4; i++) {
        texts.add(it2.ask(culprit, 'alibi', 'neutral', '').text);
      }
      expect(texts.length, greaterThan(1));
    }
  });

  test('constant pressure makes a suspect demand a lawyer', () {
    final c = CaseData(CaseGenerator.generate(category: 'theft', difficulty: 'hard', seed: 7));
    final it = Interrogator(c, Random(3));
    final sid = '${c.suspects.first['id']}';
    var lawyer = false;
    for (var i = 0; i < 14; i++) {
      if (it.ask(sid, 'alibi', 'accuse', '').lawyer) lawyer = true;
    }
    expect(lawyer, isTrue);
  });

  test('legacy cases still interrogate', () async {
    final cases = await CaseLoader.loadAll();
    for (final c in cases) {
      final it = Interrogator(c, Random(1));
      final sid = '${c.suspects.first['id']}';
      expect(it.ask(sid, 'alibi', 'neutral', '').text.isNotEmpty, isTrue);
    }
  });

  test('win rate is a safe whole percentage', () {
    expect(winRatePercent(0, 0), 0);
    expect(winRatePercent(4, 1), 25);
    expect(winRatePercent(3, 2), 67);
    expect(winRatePercent(5, 9), 100);
    expect(winRatePercent(5, -2), 0);
  });

  test('badges follow stats and unlock nothing else', () {
    final none = badgesFor(wins: 0, played: 0, lost: 0, bestStreak: 0, rankIdx: 0, winRatePct: 0);
    expect(none.where((b) => b.earned), isEmpty);
    final some = badgesFor(wins: 5, played: 6, lost: 1, bestStreak: 3, rankIdx: 2, winRatePct: 83);
    expect(some.where((b) => b.earned).length, 5);
  });

  test('every scenario is complete', () {
    expect(scenarios.map((s) => s.id).toSet().length, scenarios.length);
    for (final s in scenarios) {
      expect(s.roles.length, greaterThanOrEqualTo(7), reason: s.id);
      expect(s.zones.length, greaterThanOrEqualTo(8), reason: s.id);
      expect(s.titles, isNotEmpty, reason: s.id);
      expect(s.places, isNotEmpty, reason: s.id);
      expect(s.means, isNotEmpty, reason: s.id);
    }
    for (final cat in CaseGenerator.categories) {
      expect(scenarios.where((s) => s.cat == cat).length, greaterThanOrEqualTo(5), reason: cat);
    }
  });

  test('every scenario and difficulty builds a valid, playable case', () {
    for (final cat in CaseGenerator.categories) {
      for (final diff in CaseGenerator.difficulties) {
        for (var seed = 1; seed <= 25; seed++) {
          final j = CaseGenerator.generate(category: cat, difficulty: diff, seed: seed);
          expect(CaseGenerator.validate(j, players: 6), isNull, reason: '$cat $diff $seed');
        }
      }
    }
  });

  test('detective bot returns valid and distinct cases', () {
    final ids = <String>{};
    for (var i = 0; i < 40; i++) {
      final players = 1 + i % 6;
      final j = CaseGenerator.generateChecked(players: players);
      expect(CaseGenerator.validate(j, players: players), isNull);
      checkCase(CaseData(j));
      ids.add('${j['id']}');
    }
    expect(ids.length, 40);
  });

  test('relay address is normalized and validated', () {
    expect(normalizeRelayUrl('  https://case007.example.workers.dev/ '), 'wss://case007.example.workers.dev');
    expect(normalizeRelayUrl('wss://a.b.dev///'), 'wss://a.b.dev');
    expect(normalizeRelayUrl('ws://localhost:8787'), 'ws://localhost:8787');
    expect(normalizeRelayUrl('http://example.com'), isNull);
    expect(normalizeRelayUrl('ws://example.com'), isNull);
    expect(normalizeRelayUrl(''), isNull);
    expect(normalizeRelayUrl('wss://'), isNull);
  });
}
