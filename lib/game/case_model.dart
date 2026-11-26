import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/util.dart';

class CaseData {
  CaseData(this.j);
  final J j;

  String get id => j['id'] as String;
  String get title => j['title'] as String;
  String get difficulty => j['difficulty'] as String;
  String get category => j['category'] as String;
  String get brief => j['brief'] as String;
  int get minPlayers => (j['minPlayers'] as num).toInt();
  int get maxPlayers => (j['maxPlayers'] as num).toInt();
  bool get generated => j['generated'] == true;
  List<J> get roles => asList(j['roles']);
  List<J> get suspects => asList(j['suspects']);
  List<J> get witnesses => asList(j['witnesses']);
  List<J> get motives => asList(j['motives']);
  List<J> get evidence => asList(j['evidence']);
  J get solution => Map<String, dynamic>.from(j['solution'] as Map);
  J get sim => j['sim'] is Map ? Map<String, dynamic>.from(j['sim'] as Map) : <String, dynamic>{};
  int get labBudget => (sim['lab'] as num?)?.toInt() ?? (difficulty == 'easy' ? 5 : (difficulty == 'hard' ? 3 : 4));
  bool get hasPrints => evidence.any((e) => e['type'] == 'print');
  Set<String> get suspectIds => suspects.map((e) => e['id'] as String).toSet();
  Set<String> get motiveIds => motives.map((e) => e['id'] as String).toSet();
  String get stamp => generated ? 'AI ${id.substring(id.length - 4)}' : 'CASE ${id.split('_').last}';

  /// What clients may know about a person: never the hidden profile.
  static J publicPerson(J s) => {'id': s['id'], 'name': s['name'], 'role': s['role'], 'bio': s['bio']};

  J? evidenceById(String id) {
    for (final e in evidence) {
      if (e['id'] == id) return e;
    }
    return null;
  }

  J view(J e) => {
        'id': e['id'],
        'type': e['type'],
        'title': e['title'],
        'content': e['content'],
        'scene': e['scene'] ?? '',
        'caption': e['caption'] ?? '',
        if (e['print'] is Map) 'print': e['print'],
      };

  String get diffLabel => const {
        'easy': 'آسان',
        'standard': 'استاندارد',
        'hard': 'سخت',
      }[difficulty]!;

  String get catLabel => const {
        'theft': 'سرقت',
        'murder': 'قتل',
        'espionage': 'جاسوسی',
      }[category] ?? category;

  static const catList = ['murder', 'theft', 'espionage'];
}

class CaseLoader {
  static List<CaseData>? _cache;

  static Future<List<CaseData>> loadAll() async {
    if (_cache != null) return _cache!;
    final out = <CaseData>[];
    for (final id in ['case_003', 'case_001', 'case_004', 'case_002', 'case_005']) {
      final s = await rootBundle.loadString('assets/cases/$id.json');
      out.add(CaseData(jsonDecode(s) as Map<String, dynamic>));
    }
    _cache = out;
    return out;
  }
}
