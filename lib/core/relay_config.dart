import 'store.dart';

/// Address of your deployed relay (see relay/README.md), for example
/// `wss://case007-relay.yourname.workers.dev`. Leave empty to ship without a
/// default; players can still type their own in Settings.
const String kRelayUrl = 'wss://case007-relay.rea1spy6969.workers.dev';
/// Turns what a person typed into a usable relay base, or null when invalid.
String? normalizeRelayUrl(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('https://')) s = 'wss://${s.substring(8)}';
  if (s.startsWith('http://localhost') || s.startsWith('http://127.0.0.1')) {
    s = 'ws://${s.substring(7)}';
  }
  final ok = s.startsWith('wss://') || s.startsWith('ws://localhost') || s.startsWith('ws://127.0.0.1');
  if (!ok) return null;
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  final u = Uri.tryParse(s);
  if (u == null || u.host.isEmpty) return null;
  return s;
}

/// The relay this phone will use: its own setting first, then the built-in one.
String effectiveRelay() => normalizeRelayUrl(Store.i.relayUrl) ?? normalizeRelayUrl(kRelayUrl) ?? '';
