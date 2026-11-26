import 'dart:io';

/// What the host needs from one player connection: send a text frame or close.
/// A LAN player is a real WebSocket; an online player is a virtual socket
/// carried through the relay.
abstract class Sock {
  void add(String data);
  Future<void> close();
}

class IoSock implements Sock {
  IoSock(this.ws);
  final WebSocket ws;

  @override
  void add(String data) => ws.add(data);

  @override
  Future<void> close() => ws.close();
}
