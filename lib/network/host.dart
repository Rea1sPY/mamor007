import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../core/util.dart';
import '../game/case_model.dart';
import '../game/distribute.dart';
import '../game/generator.dart';
import '../game/interrogation.dart';
import '../game/prints.dart';
import '../game/scoring.dart';
import 'discovery.dart';
import 'protocol.dart';
import 'relay.dart';
import 'sock.dart';

class _Conn {
  _Conn(this.pid, this.token, this.name, this.agent, this.rank, this.isHost);
  final String pid;
  final String token;
  final String name;
  final String agent;
  final int rank;
  final bool isHost;
  Sock? ws;
  bool connected = true;
  bool left = false;
  bool ready = false;
  int lastSeq = 0;
  DateTime lastSeen = DateTime.now();
  DateTime? downAt;
  final List<int> stamps = [];
  final Set<String> mids = {};
  String role = '';
  String roleDesc = '';
  List<String> evidence = [];
  J? hyp;
  String? vote;
}

class GameHost {
  GameHost({
    required this.code,
    required this.roomName,
    required this.maxPlayers,
    required this.hostPid,
    required this.cases,
  });

  final String code;
  final String roomName;
  final int maxPlayers;
  final String hostPid;
  final Map<String, CaseData> cases;
  int port = 0;

  HttpServer? _server;
  Timer? _hb;
  RelayBridge? _relay;

  /// Base address of the relay while this room is also open to online players.
  String relayBase = '';
  bool get relayOn => _relay?.online ?? false;
  final Map<String, _Conn> _players = {};
  final Set<String> _shared = {};
  final Map<String, String> _sharedBy = {};
  CaseData? _case;
  Phase _phase = Phase.lobby;
  J? _result;
  int _seq = 0;
  final Random _rnd = Random();
  Interrogator? _int;
  DiscoveryResponder? _disc;
  final Set<String> _samples = {};
  final Set<String> _labDone = {};
  final List<J> _labLog = [];
  int _labLeft = 0;

  Future<void> start() async {
    for (var p = 8765; p < 8786; p++) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, p);
        port = p;
        break;
      } catch (_) {}
    }
    if (_server == null) throw const SocketException('bind failed');
    _server!.listen(_onRequest);
    _disc = DiscoveryResponder(code, port);
    await _disc!.start();
    _hb = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  /// Opens this room to players on the internet through the relay.
  Future<String?> startRelay(String base) async {
    final b = RelayBridge(base: base, code: code, key: randId(24), onSocket: _attach);
    final e = await b.start();
    if (e != null) return e;
    _relay = b;
    relayBase = base;
    return null;
  }

  Future<void> close() async {
    _broadcast('closed', {'reason': 'میزبان بازی را بسته است.'});
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _hb?.cancel();
    await _relay?.close();
    _disc?.close();
    for (final c in _players.values) {
      try {
        await c.ws?.close();
      } catch (_) {}
    }
    try {
      await _server?.close(force: true);
    } catch (_) {}
  }

  Future<void> _onRequest(HttpRequest r) async {
    if (WebSocketTransformer.isUpgradeRequest(r)) {
      try {
        final ws = await WebSocketTransformer.upgrade(r);
        _attach(IoSock(ws), ws);
      } catch (_) {}
    } else if (r.uri.path == '/hello') {
      final ok = r.uri.queryParameters['h'] == discoveryHash(code);
      r.response.statusCode = ok ? 200 : 404;
      if (ok) r.response.write('C007');
      await r.response.close();
    } else {
      r.response.statusCode = 404;
      await r.response.close();
    }
  }

  void _attach(Sock ws, Stream<dynamic> incoming) {
    _Conn? c;
    incoming.listen(
      (raw) {
        if (raw is! String) return;
        final m = Msg.decode(raw, code);
        if (m == null) return;
        if (c == null) {
          if (m.type == 'join') c = _join(ws, m);
          return;
        }
        if (m.from != c!.pid) return;
        _handle(c!, m);
      },
      onDone: () {
        if (c != null) _drop(c!, ws);
      },
      onError: (_) {
        if (c != null) _drop(c!, ws);
      },
      cancelOnError: true,
    );
  }

  _Conn? _join(Sock ws, Msg m) {
    final d = m.data;
    final pid = m.from;
    final token = '${d['token']}';
    final name = '${d['name']}'.trim();
    if (name.isEmpty || name.length > 20 || pid.length < 4 || token.length < 8) {
      _reject(ws, 'bad_join', 'اطلاعات ورود نامعتبر است.');
      return null;
    }
    final ex = _players[pid];
    if (ex != null) {
      if (ex.token != token) {
        _reject(ws, 'duplicate', 'این بازیکن قبلاً وارد اتاق شده است.');
        return null;
      }
      if (ex.left) {
        _reject(ws, 'left', 'شما از این بازی خارج شده‌اید.');
        return null;
      }
      if (m.seq <= ex.lastSeq) return null;
      final old = ex.ws;
      ex.ws = ws;
      ex.lastSeq = m.seq;
      ex.connected = true;
      ex.downAt = null;
      ex.lastSeen = DateTime.now();
      try {
        old?.close();
      } catch (_) {}
      _send(ex, 'welcome', {'pid': pid, 'host': ex.isHost, 'room': roomName});
      _sendState(ex);
      _broadcast('lobby', _lobbyData());
      return ex;
    }
    if (_phase != Phase.lobby) {
      _reject(ws, 'started', 'بازی شروع شده و امکان ورود بازیکن جدید نیست.');
      return null;
    }
    if (_players.values.where((p) => !p.left).length >= maxPlayers) {
      _reject(ws, 'full', 'ظرفیت اتاق تکمیل است.');
      return null;
    }
    if (_players.values.any((p) => p.name == name && !p.left)) {
      _reject(ws, 'name', 'این نام قبلاً در اتاق استفاده شده است.');
      return null;
    }
    final c = _Conn(pid, token, name, '${d['agent']}', (d['rank'] as num?)?.toInt() ?? 0, pid == hostPid);
    c.ws = ws;
    c.lastSeq = m.seq;
    _players[pid] = c;
    _send(c, 'welcome', {'pid': pid, 'host': c.isHost, 'room': roomName});
    _broadcast('lobby', _lobbyData());
    return c;
  }

  void _reject(Sock ws, String codeName, String text) {
    try {
      ws.add(Msg('error', 'host', ++_seq, {'code': codeName, 'text': text}).encode(code));
      ws.close();
    } catch (_) {}
  }

  void _drop(_Conn c, Sock ws) {
    if (c.ws != ws) return;
    c.ws = null;
    c.connected = false;
    c.downAt = DateTime.now();
    if (_phase == Phase.lobby && !c.isHost) _players.remove(c.pid);
    _broadcast('lobby', _lobbyData());
    _checkProgress();
  }

  void _tick() {
    final now = DateTime.now();
    var changed = false;
    for (final c in _players.values.toList()) {
      if (c.connected && now.difference(c.lastSeen).inSeconds > 15) {
        final ws = c.ws;
        try {
          ws?.close();
        } catch (_) {}
        if (ws != null) _drop(c, ws);
      }
      if (!c.connected && !c.left && c.downAt != null && now.difference(c.downAt!).inSeconds > 90) {
        c.left = true;
        changed = true;
      }
    }
    if (changed) {
      _broadcast('lobby', _lobbyData());
      _checkProgress();
    }
  }

  void _handle(_Conn c, Msg m) {
    final now = DateTime.now().millisecondsSinceEpoch;
    c.stamps.removeWhere((t) => now - t > 1000);
    if (c.stamps.length >= 10) return;
    c.stamps.add(now);
    if (m.seq <= c.lastSeq) return;
    c.lastSeq = m.seq;
    c.lastSeen = DateTime.now();
    final d = m.data;
    switch (m.type) {
      case 'ping':
        _send(c, 'pong', {});
      case 'ready':
        if (_phase == Phase.lobby && !c.isHost) {
          c.ready = d['ready'] == true;
          _broadcast('lobby', _lobbyData());
        } else if (_phase == Phase.briefing) {
          c.ready = true;
          _broadcast('lobby', _lobbyData());
          _broadcastProgress();
          _checkProgress();
        }
      case 'chat':
        final text = '${d['text'] ?? ''}'.trim();
        final mid = '${d['mid'] ?? ''}';
        if (text.isEmpty || text.length > 400 || mid.isEmpty || c.mids.contains(mid)) return;
        c.mids.add(mid);
        _broadcast('chat', {
          'pid': c.pid,
          'name': c.name,
          'text': text,
          'mid': mid,
          'ts': DateTime.now().millisecondsSinceEpoch,
        });
      case 'share':
        if (_phase.index < Phase.investigation.index || _phase == Phase.result) return;
        final id = '${d['eid']}';
        final cs = _case;
        if (cs == null || !c.evidence.contains(id) || _shared.contains(id)) return;
        final e = cs.evidenceById(id);
        if (e == null) return;
        _shared.add(id);
        _sharedBy[id] = c.name;
        _broadcast('shared', {...cs.view(e), 'by': c.name});
      case 'hyp':
        _onHypothesis(c, d);
      case 'vote':
        if (_phase != Phase.voting || c.vote != null) return;
        final t = '${d['target']}';
        final target = _players[t];
        if (target == null || t == c.pid || target.hyp == null || target.left) return;
        c.vote = t;
        _broadcastProgress();
        _checkProgress();
      case 'leave':
        c.left = true;
        try {
          c.ws?.close();
        } catch (_) {}
        if (_phase == Phase.lobby) _players.remove(c.pid);
        _broadcast('lobby', _lobbyData());
        _checkProgress();
      case 'selectCase':
        if (!c.isHost || _phase != Phase.lobby) return;
        final cs = cases['${d['id']}'];
        if (cs == null) return;
        _case = cs;
        for (final p in _players.values) {
          if (!p.isHost) p.ready = false;
        }
        _broadcast('lobby', _lobbyData());
      case 'genCase':
        if (!c.isHost || _phase != Phase.lobby) return;
        final gen = CaseData(CaseGenerator.generateChecked(
          category: '${d['cat']}',
          difficulty: '${d['diff']}',
          players: _players.length,
        ));
        cases[gen.id] = gen;
        _case = gen;
        for (final p in _players.values) {
          if (!p.isHost) p.ready = false;
        }
        _broadcast('lobby', _lobbyData());
      case 'ask':
        _onAsk(c, d);
      case 'sample':
        _onSample(c, d);
      case 'lab':
        _onLab(c, d);
      case 'start':
        if (!c.isHost || _phase != Phase.lobby) return;
        final err = _startGame();
        if (err != null) _send(c, 'error', {'code': 'start', 'text': err});
      case 'advance':
        if (!c.isHost) return;
        if (_phase == Phase.investigation) {
          _setPhase(Phase.hypothesis);
        } else if (_phase == Phase.hypothesis) {
          _toVoting();
        } else if (_phase == Phase.voting) {
          _toResult();
        }
      case 'toLobby':
        if (!c.isHost || _phase != Phase.result) return;
        _resetToLobby();
    }
  }

  void _onAsk(_Conn c, J d) {
    final it = _int;
    if (it == null || _phase != Phase.investigation) return;
    final sid = '${d['sid']}';
    if (!it.has(sid)) return;
    final r = it.ask(sid, '${d['topic']}', '${d['tone']}', '${d['arg'] ?? ''}');
    _send(c, 'answer', {'sid': sid, 'topic': '${d['topic']}', 'arg': '${d['arg'] ?? ''}', ...r.toJson()});
  }

  void _onSample(_Conn c, J d) {
    final it = _int;
    if (it == null || _phase != Phase.investigation) return;
    final sid = '${d['sid']}';
    if (!it.has(sid)) return;
    final r = it.sample(sid);
    _send(c, 'answer', {'sid': sid, 'topic': 'sample', 'arg': '', ...r.toJson()});
    if (r.flag == 'sample') {
      _samples.add(sid);
      _broadcast('samples', {'list': _samples.toList()});
    }
  }

  String _printOwner(CaseData cs, String eid) {
    final pr = cs.sim['prints'];
    if (pr is Map) {
      final e = pr[eid];
      if (e is Map) return '${e['owner']}';
    }
    return 'unknown';
  }

  void _onLab(_Conn c, J d) {
    final cs = _case;
    if (cs == null || _phase != Phase.investigation) return;
    final pid = '${d['print']}';
    final who = '${d['sid']}';
    final ev = cs.evidenceById(pid);
    if (ev == null || ev['type'] != 'print' || !(c.evidence.contains(pid) || _shared.contains(pid))) return;
    if (_labLeft <= 0) {
      _send(c, 'error', {'code': 'lab', 'text': 'اعتبار آزمایشگاه تمام شده است.'});
      return;
    }
    if (who != 'victim' && !_samples.contains(who)) {
      _send(c, 'error', {'code': 'lab', 'text': 'هنوز از این فرد نمونهٔ اثر انگشت گرفته نشده است.'});
      return;
    }
    if (!_labDone.add('$pid|$who')) {
      _send(c, 'error', {'code': 'lab', 'text': 'این مقایسه قبلاً انجام شده است.'});
      return;
    }
    final fingers = cs.sim['fingers'];
    final fg = fingers is Map && fingers[who] is Map ? Map<String, dynamic>.from(fingers[who] as Map) : null;
    if (fg == null) return;
    var name = 'قربانی';
    for (final s in cs.suspects) {
      if (s['id'] == who) name = '${s['name']}';
    }
    final res = labCompare(Map<String, dynamic>.from(ev['print'] as Map), fg, _printOwner(cs, pid) == who, _rnd);
    _labLeft--;
    final entry = {
      'print': pid,
      'sid': who,
      'name': name,
      'title': ev['title'],
      'verdict': res['verdict'],
      'text': labText(res, name),
      'left': _labLeft,
      'by': c.name,
      'pp': ev['print'],
      'sp': {'p': fg['p'], 's': fg['s']},
    };
    _labLog.add(entry);
    _broadcast('labres', entry);
  }

  void _onHypothesis(_Conn c, J h) {
    final cs = _case;
    if (cs == null || _phase != Phase.hypothesis || c.hyp != null) return;
    final su = '${h['suspect']}';
    final mo = '${h['motive']}';
    if (!cs.suspectIds.contains(su) || !cs.motiveIds.contains(mo)) return;
    final raw = h['evidence'] is List ? (h['evidence'] as List).map((e) => '$e').toSet() : <String>{};
    final ev = raw.where((e) => c.evidence.contains(e) || _shared.contains(e)).toList();
    if (ev.isEmpty) {
      _send(c, 'error', {'code': 'hyp', 'text': 'حداقل یک مدرک را انتخاب کنید.'});
      return;
    }
    var rs = '${h['reasoning'] ?? ''}'.trim();
    if (rs.length > 600) rs = rs.substring(0, 600);
    c.hyp = {'suspect': su, 'motive': mo, 'evidence': ev, 'reasoning': rs};
    _broadcastProgress();
    _checkProgress();
  }

  String? _startGame() {
    final cs = _case;
    if (cs == null) return 'ابتدا یک پرونده انتخاب کنید.';
    final act = _players.values.where((p) => !p.left && p.connected).toList();
    if (act.length < max(1, cs.minPlayers) || act.length > cs.maxPlayers) {
      return 'این پرونده برای ${cs.minPlayers} تا ${cs.maxPlayers} بازیکن است.';
    }
    if (act.any((p) => !p.isHost && !p.ready)) return 'همه بازیکنان باید آماده باشند.';
    final rnd = Random(DateTime.now().microsecondsSinceEpoch);
    final dist = distributeEvidence(act.map((p) => p.pid).toList(), cs.evidence, rnd);
    final roles = cs.roles..shuffle(rnd);
    for (final p in _players.values) {
      p.ready = false;
      p.hyp = null;
      p.vote = null;
      p.evidence = [];
    }
    for (var i = 0; i < act.length; i++) {
      final p = act[i];
      p.evidence = dist[p.pid]!;
      final r = roles[i % roles.length];
      p.role = '${r['name']}';
      p.roleDesc = '${r['desc']}';
    }
    _shared.clear();
    _sharedBy.clear();
    _samples.clear();
    _labDone.clear();
    _labLog.clear();
    _labLeft = cs.hasPrints ? cs.labBudget : 0;
    _int = Interrogator(cs, Random(DateTime.now().microsecondsSinceEpoch));
    _result = null;
    _phase = Phase.briefing;
    for (final p in act) {
      _sendIntel(p);
    }
    _setPhase(Phase.briefing);
    return null;
  }

  void _setPhase(Phase p) {
    _phase = p;
    if (p == Phase.investigation) {
      for (final c in _players.values) {
        c.ready = false;
      }
    }
    _broadcast('phase', {
      'phase': p.name,
      if (p == Phase.voting) 'hyps': _hypList(),
      if (p == Phase.result) 'result': _result,
    });
    _broadcast('lobby', _lobbyData());
    _broadcastProgress();
  }

  void _checkProgress() {
    final act = _players.values.where((p) => !p.left).toList();
    if (act.isEmpty) return;
    switch (_phase) {
      case Phase.briefing:
        if (act.every((p) => p.ready)) _setPhase(Phase.investigation);
      case Phase.hypothesis:
        if (act.every((p) => p.hyp != null)) _toVoting();
      case Phase.voting:
        if (_votersDone(act)) _toResult();
      default:
        break;
    }
  }

  bool _votersDone(List<_Conn> act) {
    for (final p in act) {
      final hasTarget = act.any((q) => q.pid != p.pid && q.hyp != null);
      if (hasTarget && p.vote == null) return false;
    }
    return true;
  }

  void _toVoting() {
    if (_players.values.where((p) => !p.left && p.hyp != null).isEmpty) {
      _toResult();
    } else {
      _setPhase(Phase.voting);
      _checkProgress();
    }
  }

  void _toResult() {
    final cs = _case!;
    final sol = cs.solution;
    final hyps = _hypList();
    final votesByPid = <String, int>{};
    for (final p in _players.values) {
      final v = p.vote;
      if (v != null) votesByPid[v] = (votesByPid[v] ?? 0) + 1;
    }
    final verdict = pickVerdict(hyps, votesByPid);
    final won = verdict != null && verdict == '${sol['culprit']}';
    final rows = <J>[];
    for (final p in _players.values) {
      if (p.left && p.hyp == null) continue;
      rows.add({
        'pid': p.pid,
        'name': p.name,
        'submitted': p.hyp != null,
        'suspect': p.hyp?['suspect'],
        'votes': votesByPid[p.pid] ?? 0,
        'grade': p.hyp == null ? null : gradeHypothesis(p.hyp!, sol),
      });
    }
    _result = {
      'solution': {
        'culprit': sol['culprit'],
        'motive': sol['motive'],
        'explanation': sol['explanation'],
        'keyEvidence': [
          for (final id in (sol['keyEvidence'] as List))
            {'id': id, 'title': cs.evidenceById('$id')?['title'] ?? ''}
        ],
      },
      'rows': rows,
      'verdict': verdict,
      'won': won,
      'caseId': cs.id,
    };
    _setPhase(Phase.result);
  }

  void _resetToLobby() {
    _players.removeWhere((_, p) => !p.isHost && (p.left || !p.connected));
    for (final p in _players.values) {
      p.ready = false;
      p.hyp = null;
      p.vote = null;
      p.evidence = [];
      p.role = '';
    }
    _shared.clear();
    _sharedBy.clear();
    _samples.clear();
    _labDone.clear();
    _labLog.clear();
    _int = null;
    _result = null;
    _setPhase(Phase.lobby);
  }

  List<J> _hypList() {
    final cs = _case!;
    return [
      for (final p in _players.values)
        if (p.hyp != null && !p.left)
          {
            'pid': p.pid,
            'name': p.name,
            'suspect': p.hyp!['suspect'],
            'motive': p.hyp!['motive'],
            'reasoning': p.hyp!['reasoning'],
            'evidence': [
              for (final id in (p.hyp!['evidence'] as List))
                {'id': id, 'title': cs.evidenceById('$id')?['title'] ?? ''}
            ],
          }
    ];
  }

  J _lobbyData() => {
        'room': roomName,
        'cap': maxPlayers,
        'phase': _phase.name,
        'caseId': _case?.id ?? '',
        'caseTitle': _case?.title ?? '',
        'diff': _case?.difficulty ?? '',
        'min': _case?.minPlayers ?? 0,
        'max': _case?.maxPlayers ?? 0,
        'players': [
          for (final p in _players.values)
            if (!p.left)
              {
                'pid': p.pid,
                'name': p.name,
                'ready': p.ready,
                'up': p.connected,
                'host': p.isHost,
                'rank': p.rank,
                'agent': p.agent,
              }
        ],
      };

  void _sendState(_Conn c) {
    _send(c, 'lobby', _lobbyData());
    if (_phase == Phase.lobby) return;
    _sendIntel(c);
    _send(c, 'phase', {
      'phase': _phase.name,
      if (_phase == Phase.voting) 'hyps': _hypList(),
      if (_phase == Phase.result) 'result': _result,
    });
    _broadcastProgress();
  }

  void _sendIntel(_Conn c) {
    final cs = _case;
    if (cs == null) return;
    _send(c, 'intel', {
      'caseId': cs.id,
      'title': cs.title,
      'brief': cs.brief,
      'role': c.role,
      'roleDesc': c.roleDesc,
      'suspects': [for (final x in cs.suspects) CaseData.publicPerson(x)],
      'witnesses': [for (final x in cs.witnesses) CaseData.publicPerson(x)],
      'diff': cs.difficulty,
      'samples': _samples.toList(),
      'labLeft': _labLeft,
      'labLog': _labLog,
      'motives': cs.motives,
      'evidence': [for (final id in c.evidence) cs.view(cs.evidenceById(id)!)],
      'shared': [
        for (final id in _shared) {...cs.view(cs.evidenceById(id)!), 'by': _sharedBy[id] ?? ''}
      ],
      'submitted': c.hyp != null,
      'voted': c.vote != null,
    });
  }

  void _broadcastProgress() {
    final act = _players.values.where((p) => !p.left).toList();
    int done = 0;
    int total = act.length;
    switch (_phase) {
      case Phase.briefing:
        done = act.where((p) => p.ready).length;
      case Phase.hypothesis:
        done = act.where((p) => p.hyp != null).length;
      case Phase.voting:
        final voters = act.where((p) => act.any((q) => q.pid != p.pid && q.hyp != null)).toList();
        done = voters.where((p) => p.vote != null).length;
        total = voters.length;
      default:
        break;
    }
    _broadcast('progress', {'done': done, 'total': total});
  }

  void _send(_Conn c, String type, J data) {
    final ws = c.ws;
    if (ws == null) return;
    try {
      ws.add(Msg(type, 'host', ++_seq, data).encode(code));
    } catch (_) {}
  }

  void _broadcast(String type, J data) {
    for (final c in _players.values) {
      if (!c.left || _phase == Phase.lobby) _send(c, type, data);
    }
  }
}
