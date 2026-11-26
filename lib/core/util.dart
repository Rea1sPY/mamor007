import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

typedef J = Map<String, dynamic>;

final Random _rng = Random.secure();

String randId([int n = 16]) {
  const a = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(n, (_) => a[_rng.nextInt(a.length)]).join();
}

String newRoomCode() {
  const a = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return List.generate(6, (_) => a[_rng.nextInt(a.length)]).join();
}

String newAgentCode() => List.generate(6, (_) => _rng.nextInt(10)).join();

String hmac(String key, String data) =>
    Hmac(sha256, utf8.encode(key)).convert(utf8.encode(data)).toString();

bool constEq(String a, String b) {
  if (a.length != b.length) return false;
  var r = 0;
  for (var i = 0; i < a.length; i++) {
    r |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return r == 0;
}

List<J> asList(Object? o) =>
    ((o as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

String fa(Object v) {
  const f = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return v.toString().split('').map((c) {
    final d = int.tryParse(c);
    return d == null ? c : f[d];
  }).join();
}

/// Whole-number win percentage; 0 when nothing was played.
int winRatePercent(int played, int wins) =>
    played <= 0 ? 0 : (wins.clamp(0, played) * 100 / played).round();

int seedOf(String s) => s.codeUnits.fold(7, (a, b) => (a * 31 + b) & 0x7fffffff);

int _addrRank(String a) => a.startsWith('192.168.')
    ? 0
    : a.startsWith('172.')
        ? 1
        : a.startsWith('10.')
            ? 2
            : 3;

Future<List<String>> localAddresses() async {
  final out = <String>[];
  try {
    final ifs = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    for (final i in ifs) {
      for (final a in i.addresses) {
        out.add(a.address);
      }
    }
  } catch (_) {}
  out.sort((a, b) => _addrRank(a).compareTo(_addrRank(b)));
  return out;
}
