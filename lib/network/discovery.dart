import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/util.dart';

const discoveryPort = 8799;

/// The room code is never broadcast; only a hash of it.
String discoveryHash(String code) => hmac('case007-discovery', code.toUpperCase()).substring(0, 10);

class FoundHost {
  const FoundHost(this.ip, this.port);
  final String ip;
  final int port;
}

/// Host side: answers "who has room X?" questions on the LAN.
class DiscoveryResponder {
  DiscoveryResponder(this.code, this.tcpPort);
  final String code;
  final int tcpPort;
  RawDatagramSocket? _sock;

  Future<void> start() async {
    try {
      final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort, reuseAddress: true);
      s.broadcastEnabled = true;
      _sock = s;
      final h = discoveryHash(code);
      s.listen((ev) {
        if (ev != RawSocketEvent.read) return;
        final d = s.receive();
        if (d == null) return;
        final msg = utf8.decode(d.data, allowMalformed: true);
        if (msg == 'C007?$h') {
          s.send(utf8.encode('C007!$h:$tcpPort'), d.address, d.port);
        }
      });
    } catch (_) {
      _sock = null;
    }
  }

  void close() {
    try {
      _sock?.close();
    } catch (_) {}
    _sock = null;
  }
}

Future<bool> _probe(String ip, int port, String h) async {
  final c = HttpClient()..connectionTimeout = const Duration(milliseconds: 700);
  try {
    final req = await c.getUrl(Uri.parse('http://$ip:$port/hello?h=$h')).timeout(const Duration(seconds: 1));
    final res = await req.close().timeout(const Duration(seconds: 1));
    final body = await res.transform(utf8.decoder).join();
    return res.statusCode == 200 && body == 'C007';
  } catch (_) {
    return false;
  } finally {
    c.close(force: true);
  }
}

/// Client side: finds the host of [code] without any IP typing.
Future<FoundHost?> discoverHost(String code, {Duration timeout = const Duration(seconds: 10)}) async {
  final h = discoveryHash(code);
  final mine = await localAddresses();
  if (mine.isEmpty) return null;
  final done = Completer<FoundHost?>();
  RawDatagramSocket? sock;
  Timer? beat;
  Timer? scanStart;
  Timer? stop;

  void finish(FoundHost? f) {
    if (done.isCompleted) return;
    done.complete(f);
  }

  try {
    sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    sock.broadcastEnabled = true;
    sock.listen((ev) {
      if (ev != RawSocketEvent.read) return;
      final d = sock?.receive();
      if (d == null) return;
      final msg = utf8.decode(d.data, allowMalformed: true);
      final pre = 'C007!$h:';
      if (msg.startsWith(pre)) {
        final p = int.tryParse(msg.substring(pre.length));
        if (p != null) finish(FoundHost(d.address.address, p));
      }
    });
  } catch (_) {
    sock = null;
  }

  final targets = <String>{'255.255.255.255'};
  for (final ip in mine) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      targets.add('${parts[0]}.${parts[1]}.${parts[2]}.255');
      targets.add('${parts[0]}.${parts[1]}.${parts[2]}.1');
    }
  }
  final payload = utf8.encode('C007?$h');
  void blast() {
    for (final t in targets) {
      try {
        sock?.send(payload, InternetAddress(t), discoveryPort);
      } catch (_) {}
    }
  }

  blast();
  beat = Timer.periodic(const Duration(milliseconds: 600), (_) => blast());

  // Fallback: ask every address of the local /24 over HTTP.
  scanStart = Timer(const Duration(milliseconds: 2500), () async {
    for (final ip in mine) {
      final parts = ip.split('.');
      if (parts.length != 4) continue;
      final base = '${parts[0]}.${parts[1]}.${parts[2]}';
      for (var start = 1; start < 255 && !done.isCompleted; start += 50) {
        final batch = <Future<void>>[];
        for (var i = start; i < start + 50 && i < 255; i++) {
          final target = '$base.$i';
          if (target == ip) continue;
          batch.add(() async {
            for (final port in [8765, 8766, 8767]) {
              if (done.isCompleted) return;
              if (await _probe(target, port, h)) {
                finish(FoundHost(target, port));
                return;
              }
            }
          }());
        }
        await Future.wait(batch);
      }
    }
  });

  stop = Timer(timeout, () => finish(null));
  final result = await done.future;
  beat.cancel();
  scanStart.cancel();
  stop.cancel();
  try {
    sock?.close();
  } catch (_) {}
  return result;
}
