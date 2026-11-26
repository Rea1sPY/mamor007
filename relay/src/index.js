// CASE 007 online relay for Cloudflare Workers (Durable Objects, free plan).
//
// It never reads game data. The host phone opens one socket per room, every
// player opens one socket, and the relay copies text frames between them.
// Frames are already signed by the game (HMAC with the room code).
//
//   host   wss://<worker>/r/<CODE>/host?k=<secret>
//   player wss://<worker>/r/<CODE>/c
//
// Relay <-> host envelope (JSON text):
//   relay -> host: {k:"open",c:id} | {k:"msg",c:id,d:frame} | {k:"close",c:id}
//   host -> relay: {k:"msg",c:id,d:frame} | {k:"kick",c:id} | {k:"ping"} | {k:"bye"}

import { DurableObject } from "cloudflare:workers";

const ROOM_RE = /^\/r\/([A-HJ-NP-Z2-9]{6})\/(host|c)$/;
const MAX_PLAYERS = 12;
const MAX_CLIENT_FRAME = 64 * 1024;
const MAX_HOST_FRAME = 512 * 1024;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/" || url.pathname === "/health") {
      return new Response("CASE 007 relay OK", { headers: { "content-type": "text/plain" } });
    }
    const m = ROOM_RE.exec(url.pathname);
    if (!m) return new Response("not found", { status: 404 });
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("websocket expected", { status: 426 });
    }
    const stub = env.ROOMS.get(env.ROOMS.idFromName(m[1]));
    return stub.fetch(request);
  },
};

export class Room extends DurableObject {
  async fetch(request) {
    const url = new URL(request.url);
    const role = ROOM_RE.exec(url.pathname)[2];
    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];

    if (role === "host") {
      const key = url.searchParams.get("k") || "";
      if (key.length < 16 || key.length > 64) return new Response("bad key", { status: 400 });
      const stored = await this.ctx.storage.get("hk");
      if (stored && stored !== key) return new Response("room taken", { status: 403 });
      if (!stored) await this.ctx.storage.put("hk", key);
      // A reconnecting host replaces its own earlier socket.
      for (const old of this.ctx.getWebSockets("host")) {
        try {
          old.serializeAttachment({ role: "host", replaced: true });
          old.close(4000, "replaced");
        } catch (_) {}
      }
      this.ctx.acceptWebSocket(server, ["host"]);
      server.serializeAttachment({ role: "host" });
      return new Response(null, { status: 101, webSocket: client });
    }

    const host = this.ctx.getWebSockets("host")[0];
    if (!host) return new Response("no host", { status: 503 });
    if (this.ctx.getWebSockets().length > MAX_PLAYERS) return new Response("room full", { status: 429 });

    const id = crypto.randomUUID().replace(/-/g, "").slice(0, 12);
    this.ctx.acceptWebSocket(server, ["c:" + id]);
    server.serializeAttachment({ role: "c", id });
    this._toHost({ k: "open", c: id });
    return new Response(null, { status: 101, webSocket: client });
  }

  _toHost(obj) {
    const host = this.ctx.getWebSockets("host")[0];
    if (!host) return false;
    try {
      host.send(JSON.stringify(obj));
      return true;
    } catch (_) {
      return false;
    }
  }

  async webSocketMessage(ws, message) {
    if (typeof message !== "string") return;
    const att = ws.deserializeAttachment() || {};

    if (att.role === "c") {
      if (message.length > MAX_CLIENT_FRAME) return;
      if (!this._toHost({ k: "msg", c: att.id, d: message })) {
        try {
          ws.close(4001, "host gone");
        } catch (_) {}
      }
      return;
    }

    if (att.role === "host") {
      if (message.length > MAX_HOST_FRAME) return;
      let o;
      try {
        o = JSON.parse(message);
      } catch (_) {
        return;
      }
      if (o.k === "msg" && typeof o.c === "string" && typeof o.d === "string") {
        const t = this.ctx.getWebSockets("c:" + o.c)[0];
        if (t) {
          try {
            t.send(o.d);
          } catch (_) {}
        }
      } else if (o.k === "kick" && typeof o.c === "string") {
        const t = this.ctx.getWebSockets("c:" + o.c)[0];
        if (t) {
          try {
            t.close(1000, "kicked");
          } catch (_) {}
        }
      } else if (o.k === "bye") {
        await this._closeRoom();
      }
      // {k:"ping"} only keeps the socket warm.
    }
  }

  async webSocketClose(ws, code, reason, wasClean) {
    const att = ws.deserializeAttachment() || {};
    try {
      ws.close(code === 1005 || code === 1006 ? 1000 : code, "bye");
    } catch (_) {}
    if (att.role === "c") {
      this._toHost({ k: "close", c: att.id });
    } else if (att.role === "host" && !att.replaced) {
      // Players are dropped; they reconnect for a while and the host app
      // re-opens its socket with the same secret.
      for (const c of this.ctx.getWebSockets()) {
        const a = c.deserializeAttachment() || {};
        if (a.role === "c") {
          try {
            c.close(4001, "host gone");
          } catch (_) {}
        }
      }
    }
  }

  async webSocketError(ws, error) {
    await this.webSocketClose(ws, 1011, "error", false);
  }

  async _closeRoom() {
    for (const c of this.ctx.getWebSockets()) {
      try {
        c.close(1000, "room closed");
      } catch (_) {}
    }
    await this.ctx.storage.deleteAll();
  }
}
