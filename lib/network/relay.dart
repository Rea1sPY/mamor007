import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'sock.dart';

class _RelaySock implements Sock {
  _RelaySock(this.id, this._bridge);
  final String id;
  final RelayBridge _bridge;
  final StreamController<dynamic> incoming = StreamController<dynamic>();
  bool _closed = false;

  @override
  void add(String data) {
    if (_closed) return;
    _bridge._out({'k': 'msg', 'c': id, 'd': data});
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _bridge._out({'k': 'kick', 'c': id});
    _bridge._socks.remove(id);
    if (!incoming.isClosed) await incoming.close();
  }

  void remoteClosed() {
    _closed = true;
    if (!incoming.isClosed) incoming.close();
  }
}

/// Host side of the online relay. Keeps one WebSocket to the relay and turns
/// every online player into a virtual [Sock] for the game host.
class RelayBridge {
  RelayBridge({required this.base, required this.code, required this.key, required this.onSocket});

  final String base;
  final String code;

  /// Secret that proves this phone is the room's host when it reconnects.
  final String key;
  final void Function(Sock sock, Stream<dynamic> incoming) onSocket;

  final Map<String, _RelaySock> _socks = {};
  WebSocket? _ws;
  Timer? _ping;
  bool _closed = false;
  bool online = false;

  Future<String?> start() => _connect();

  Future<String?> _connect() async {
    try {
      final ws = await WebSocket.connect('$base/r/$code/host?k=$key').timeout(const Duration(seconds: 10));
      _ws = ws;
      online = true;
      ws.listen(_onRaw, onDone: () => _down(ws), onError: (_) => _down(ws), cancelOnError: true);
      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 25), (_) => _out({'k': 'ping'}));
      return null;
    } catch (_) {
      return 'اتصال به سرور آنلاین برقرار نشد. آدرس سرور و اینترنت را بررسی کنید.';
    }
  }

  void _down(WebSocket ws) {
    if (ws != _ws) return;
    online = false;
    _ping?.cancel();
    for (final s in _socks.values.toList()) {
      s.remoteClosed();
    }
    _socks.clear();
    if (!_closed) _retry(1);
  }

  Future<void> _retry(int n) async {
    if (_closed || n > 40) return;
    await Future<void>.delayed(Duration(seconds: n < 5 ? 2 : 4));
    if (_closed) return;
    final e = await _connect();
    if (e != null) _retry(n + 1);
  }

  void _onRaw(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic> o;
    try {
      o = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final id = '${o['c']}';
    switch ('${o['k']}') {
      case 'open':
        if (id.isEmpty || id == 'null' || _socks.containsKey(id)) return;
        final s = _RelaySock(id, this);
        _socks[id] = s;
        onSocket(s, s.incoming.stream);
      case 'msg':
        final d = o['d'];
        if (d is String) {
          final s = _socks[id];
          if (s != null && !s.incoming.isClosed) s.incoming.add(d);
        }
      case 'close':
        _socks.remove(id)?.remoteClosed();
    }
  }

  void _out(Map<String, dynamic> m) {
    try {
      _ws?.add(jsonEncode(m));
    } catch (_) {}
  }

  Future<void> close() async {
    _closed = true;
    _ping?.cancel();
    _out({'k': 'bye'});
    await Future<void>.delayed(const Duration(milliseconds: 120));
    try {
      await _ws?.close();
    } catch (_) {}
    for (final s in _socks.values.toList()) {
      s.remoteClosed();
    }
    _socks.clear();
    online = false;
  }
}
