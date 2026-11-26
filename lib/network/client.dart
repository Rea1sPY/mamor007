import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/feedback.dart';
import '../core/relay_config.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'discovery.dart';
import 'host.dart';
import 'protocol.dart';

class ChatLine {
  const ChatLine(this.pid, this.name, this.text, {this.system = false});
  final String pid;
  final String name;
  final String text;
  final bool system;
}

class GameClient extends ChangeNotifier {
  GameClient._();
  static final GameClient i = GameClient._();

  GameHost? hostServer;

  /// Relay base address when this phone joined through the internet, else empty.
  String relay = '';
  List<String> ips = [];
  int ipIndex = 0;

  String ip = '';
  int port = 0;
  String code = '';
  String token = '';
  String myPid = '';
  String myName = '';
  bool isHost = false;
  bool joined = false;
  bool reconnecting = false;
  bool lost = false;
  String? closedReason;
  String? lastError;

  String roomName = '';
  int cap = 6;
  String caseId = '';
  String caseTitle = '';
  String diff = '';
  int minP = 0;
  int maxP = 0;
  List<J> players = [];

  Phase phase = Phase.lobby;
  J? intel;
  List<J> evidence = [];
  Set<String> mineIds = {};
  Set<String> sharedIds = {};
  List<ChatLine> chat = [];
  int chatSeen = 0;
  List<J> hyps = [];
  int done = 0;
  int total = 0;
  bool submitted = false;
  bool voted = false;
  J? result;
  bool resultApplied = false;
  bool rankedUp = false;
  List<J> witnesses = [];
  Set<String> samples = {};
  int labLeft = 0;
  List<J> labLog = [];
  String caseDiff = '';
  final Set<String> waiting = {};
  String? freshAnswer;

  final Map<String, Offset> pos = {};
  final Set<String> links = {};
  final Map<String, List<J>> notes = {};
  final Map<String, List<J>> interro = {};
  final Map<String, int> interroCount = {};
  double boardScale = 0.9;
  Offset boardOff = Offset.zero;

  WebSocket? _ws;
  Timer? _ping;
  Completer<String?>? _joinC;
  bool _intentional = false;
  bool _netFail = false;
  int _seq = 0;
  int _hostSeq = 0;
  final Set<String> _seenMid = {};

  J? get me {
    for (final p in players) {
      if (p['pid'] == myPid) return p;
    }
    return null;
  }

  List<J> get suspects => asList(intel?['suspects']);
  List<J> get motives => asList(intel?['motives']);

  String suspectName(String id) {
    for (final s in suspects) {
      if (s['id'] == id) return '${s['name']}';
    }
    return id;
  }

  String motiveText(String id) {
    for (final m in motives) {
      if (m['id'] == id) return '${m['text']}';
    }
    return id;
  }

  J? evById(String id) {
    for (final e in evidence) {
      if (e['id'] == id) return e;
    }
    return null;
  }

  void reset() {
    phase = Phase.lobby;
    intel = null;
    evidence = [];
    mineIds = {};
    sharedIds = {};
    chat = [];
    chatSeen = 0;
    hyps = [];
    done = 0;
    total = 0;
    submitted = false;
    voted = false;
    result = null;
    resultApplied = false;
    rankedUp = false;
    witnesses = [];
    samples = {};
    labLeft = 0;
    labLog = [];
    caseDiff = '';
    waiting.clear();
    freshAnswer = null;
    pos.clear();
    links.clear();
    notes.clear();
    interro.clear();
    interroCount.clear();
    boardScale = 0.9;
    boardOff = Offset.zero;
    caseId = '';
    caseTitle = '';
    players = [];
    _seenMid.clear();
  }

  Future<String?> join({
    required String ip,
    required int port,
    required String code,
    bool host = false,
    String? savedToken,
    String relay = '',
  }) async {
    _ws?.close();
    _ping?.cancel();
    reset();
    this.ip = ip;
    this.port = port;
    this.relay = relay;
    this.code = code;
    myPid = Store.i.pid;
    myName = Store.i.codename;
    isHost = host;
    token = savedToken ?? randId(24);
    joined = false;
    reconnecting = false;
    lost = false;
    closedReason = null;
    lastError = null;
    _intentional = false;
    _hostSeq = 0;
    _seq = DateTime.now().microsecondsSinceEpoch;
    return _open();
  }

  /// Joins using only the room code; the host is found on the local network.
  Future<String?> joinByCode(String code) async {
    final f = await discoverHost(code);
    if (f == null) {
      return 'میزبانی با این کد پیدا نشد. مطمئن شوید هر دو گوشی به یک Wi-Fi یا هات‌اسپات وصل‌اند و کد درست است.';
    }
    return join(ip: f.ip, port: f.port, code: code);
  }

  /// Joins through the internet relay using only the room code.
  Future<String?> joinOnline(String code, {String? base}) async {
    final b = base != null ? (normalizeRelayUrl(base) ?? '') : effectiveRelay();
    if (b.isEmpty) {
      return 'سرور بازی آنلاین تنظیم نشده است. آدرس آن را در تنظیمات وارد کنید.';
    }
    return join(ip: '', port: 0, code: code, relay: b);
  }

  Future<String?> _open() async {
    _netFail = false;
    WebSocket ws;
    final online = relay.isNotEmpty;
    try {
      ws = await WebSocket.connect(online ? '$relay/r/$code/c' : 'ws://$ip:$port')
          .timeout(Duration(seconds: online ? 12 : 6));
    } catch (_) {
      _netFail = true;
      return online
          ? 'اتصال به اتاق آنلاین برقرار نشد. کد اتاق، اینترنت و روشن‌بودن میزبان را بررسی کنید.'
          : 'اتصال به میزبان برقرار نشد. مطمئن شوید هر دو گوشی در یک شبکه یا هات‌اسپات هستند و آدرس و کد درست است.';
    }
    _ws = ws;
    _joinC = Completer<String?>();
    ws.listen(_onRaw, onDone: () => _onDown(ws), onError: (_) => _onDown(ws), cancelOnError: true);
    _send('join', {'name': myName, 'token': token, 'agent': Store.i.agent, 'rank': Store.i.rank.idx});
    final r = await _joinC!.future.timeout(const Duration(seconds: 6), onTimeout: () {
      _netFail = true;
      return 'پاسخی از میزبان دریافت نشد.';
    });
    if (r == null) {
      joined = true;
      lost = false;
      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 5), (_) => _send('ping', {}));
      if (!isHost) {
        await Store.i.saveSession({'ip': ip, 'port': port, 'code': code, 'token': token, 'room': roomName, 'relay': relay});
      }
      notifyListeners();
    } else {
      try {
        await ws.close();
      } catch (_) {}
    }
    return r;
  }

  void _onRaw(dynamic raw) {
    if (raw is! String) return;
    final m = Msg.decode(raw, code);
    if (m == null || m.from != 'host' || m.seq <= _hostSeq) return;
    _hostSeq = m.seq;
    final d = m.data;
    switch (m.type) {
      case 'welcome':
        roomName = '${d['room']}';
        if (_joinC != null && !_joinC!.isCompleted) _joinC!.complete(null);
      case 'error':
        final t = '${d['text']}';
        if (_joinC != null && !_joinC!.isCompleted) {
          _joinC!.complete(t);
        } else {
          lastError = t;
          notifyListeners();
        }
      case 'lobby':
        roomName = '${d['room']}';
        cap = (d['cap'] as num).toInt();
        caseId = '${d['caseId']}';
        caseTitle = '${d['caseTitle']}';
        diff = '${d['diff']}';
        minP = (d['min'] as num).toInt();
        maxP = (d['max'] as num).toInt();
        players = asList(d['players']);
        notifyListeners();
      case 'intel':
        intel = d;
        evidence = asList(d['evidence']);
        mineIds = evidence.map((e) => '${e['id']}').toSet();
        for (final s in asList(d['shared'])) {
          _addShared(s);
        }
        submitted = d['submitted'] == true;
        voted = d['voted'] == true;
        witnesses = asList(d['witnesses']);
        caseDiff = '${d['diff'] ?? ''}';
        samples = ((d['samples'] as List?) ?? const []).map((e) => '$e').toSet();
        labLeft = (d['labLeft'] as num?)?.toInt() ?? 0;
        labLog = asList(d['labLog']);
        notifyListeners();
      case 'samples':
        samples = ((d['list'] as List?) ?? const []).map((e) => '$e').toSet();
        notifyListeners();
      case 'labres':
        labLog.add(d);
        labLeft = (d['left'] as num?)?.toInt() ?? labLeft;
        chat.add(ChatLine('', '${d['by']}',
            'آزمایشگاه: ${d['title']} ← ${d['name']}: ${d['text']}',
            system: true));
        Fx.lab();
        notifyListeners();
      case 'answer':
        final sid = '${d['sid']}';
        waiting.remove(sid);
        freshAnswer = sid;
        interro.putIfAbsent(sid, () => []).add({
          'who': 'sus',
          'text': '${d['text']}',
          'obs': d['obs'] ?? const [],
          'flag': '${d['flag']}',
          'stage': d['stage'] ?? 0,
          'lawyer': d['lawyer'] == true,
          'topic': '${d['topic']}',
        });
        if (d['lawyer'] == true) Fx.alert();
        notifyListeners();
      case 'phase':
        _onPhase(d);
      case 'shared':
        _addShared(d);
        final by = '${d['by']}';
        chat.add(ChatLine('', by, '$by مدرک «${d['title']}» را با همه به اشتراک گذاشت.', system: true));
        Fx.share();
        notifyListeners();
      case 'chat':
        final mid = '${d['mid']}';
        if (_seenMid.add(mid)) {
          chat.add(ChatLine('${d['pid']}', '${d['name']}', '${d['text']}'));
          if ('${d['pid']}' != myPid) Fx.message();
          notifyListeners();
        }
      case 'progress':
        done = (d['done'] as num).toInt();
        total = (d['total'] as num).toInt();
        notifyListeners();
      case 'closed':
        closedReason = '${d['reason']}';
        Store.i.clearSession();
        notifyListeners();
    }
  }

  void _addShared(J e) {
    final id = '${e['id']}';
    sharedIds.add(id);
    if (evidence.every((x) => x['id'] != id)) evidence.add(e);
  }

  void _onPhase(J d) {
    final p = phaseOf('${d['phase']}');
    phase = p;
    if (p == Phase.lobby) {
      final keep = Map<String, Offset>.from(pos);
      reset();
      pos.addAll(keep);
      pos.clear();
      phase = Phase.lobby;
    }
    if (p == Phase.voting) {
      hyps = asList(d['hyps']);
    }
    if (p == Phase.result && d['result'] != null) {
      result = Map<String, dynamic>.from(d['result'] as Map);
      _applyResult();
    }
    notifyListeners();
  }

  void _applyResult() {
    if (resultApplied || result == null) return;
    resultApplied = true;
    final rows = asList(result!['rows']);
    J? mine;
    for (final r in rows) {
      if (r['pid'] == myPid) mine = r;
    }
    if (mine == null) return;
    final won = result!['won'] == true;
    Store.i
        .addResult(won: won, caseId: '${result!['caseId']}')
        .then((up) {
      rankedUp = up;
      notifyListeners();
    });
  }

  void _onDown(WebSocket ws) {
    if (ws != _ws) return;
    _ping?.cancel();
    if (_joinC != null && !_joinC!.isCompleted) {
      _netFail = true;
      _joinC!.complete('اتصال قطع شد.');
      return;
    }
    if (_intentional || closedReason != null || !joined) return;
    joined = false;
    reconnecting = true;
    notifyListeners();
    _reconnect();
  }

  Future<void> _reconnect() async {
    for (var i = 0; i < 45; i++) {
      if (_intentional || closedReason != null) return;
      await Future<void>.delayed(const Duration(seconds: 2));
      if (_intentional || closedReason != null) return;
      final r = await _open();
      if (r == null) {
        reconnecting = false;
        notifyListeners();
        return;
      }
      if (!_netFail) break;
    }
    reconnecting = false;
    lost = true;
    notifyListeners();
  }

  void _send(String type, J data) {
    final ws = _ws;
    if (ws == null) return;
    try {
      ws.add(Msg(type, myPid, ++_seq, data).encode(code));
    } catch (_) {}
  }

  void touch() => notifyListeners();
  void setReady(bool v) => _send('ready', {'ready': v});
  void sendChat(String text) => _send('chat', {'text': text, 'mid': randId(12)});
  void share(String eid) => _send('share', {'eid': eid});
  void hostSelect(String id) => _send('selectCase', {'id': id});
  void hostGenerate(String cat, String diff) => _send('genCase', {'cat': cat, 'diff': diff});

  void ask(String sid, String topic, String tone, String arg, String myLine) {
    interro.putIfAbsent(sid, () => []).add({'who': 'me', 'text': myLine});
    waiting.add(sid);
    notifyListeners();
    _send('ask', {'sid': sid, 'topic': topic, 'tone': tone, 'arg': arg});
  }

  void takeSample(String sid) {
    interro.putIfAbsent(sid, () => []).add({'who': 'me', 'text': 'لطفاً نمونهٔ اثر انگشتتان را بدهید.'});
    waiting.add(sid);
    notifyListeners();
    _send('sample', {'sid': sid});
  }

  void sendLab(String printId, String sid) => _send('lab', {'print': printId, 'sid': sid});
  void hostStart() => _send('start', {});
  void hostAdvance() => _send('advance', {});
  void hostToLobby() => _send('toLobby', {});

  void submitHypothesis(String suspect, String motive, List<String> ev, String reasoning) {
    submitted = true;
    notifyListeners();
    _send('hyp', {'suspect': suspect, 'motive': motive, 'evidence': ev, 'reasoning': reasoning});
  }

  void vote(String pid) {
    voted = true;
    notifyListeners();
    _send('vote', {'target': pid});
  }

  Future<void> leave() async {
    _intentional = true;
    _ping?.cancel();
    _send('leave', {});
    await Store.i.clearSession();
    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;
    final h = hostServer;
    hostServer = null;
    if (h != null) await h.close();
    joined = false;
    reconnecting = false;
    lost = false;
    closedReason = null;
  }
}
