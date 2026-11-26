// Simulates the relay's routing with mocks (no Cloudflare needed): node test/simulate.mjs
import assert from 'node:assert';
class Sock { constructor(){ this.sent=[]; this.closed=null; this.att=null; this.tags=[]; }
  send(m){ this.sent.push(m); } close(c,r){ this.closed=[c,r]; }
  serializeAttachment(a){ this.att=a; } deserializeAttachment(){ return this.att; } }
globalThis.WebSocketPair = function(){ return [new Sock(), new Sock()]; };
globalThis.Response = class { constructor(body, init={}){ this.status=init.status||200; this.webSocket=init.webSocket; this.body=body; } };
const store=new Map();
const all=[];
const ctx={ storage:{ get: async k=>store.get(k), put: async (k,v)=>{store.set(k,v)}, deleteAll: async()=>store.clear() },
  acceptWebSocket(ws,tags){ ws.tags=tags; all.push(ws); },
  getWebSockets(tag){ const live=all.filter(w=>!w.closed); return tag? live.filter(w=>w.tags.includes(tag)) : live; } };
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const src = fs.readFileSync(path.join(here, '../src/index.js'), 'utf8').replace(
  'import { DurableObject } from "cloudflare:workers";',
  'class DurableObject { constructor(ctx, env) { this.ctx = ctx; this.env = env; } }');
const tmp = path.join(os.tmpdir(), 'case007-relay-under-test.mjs');
fs.writeFileSync(tmp, src);
const mod = await import(pathToFileURL(tmp).href);
const room = new mod.Room(ctx,{});
const req=(p)=>({ url:'https://x.dev'+p });
// client without host -> 503
let r = await room.fetch(req('/r/ABCDEF/c')); assert.equal(r.status,503);
// bad key
r = await room.fetch(req('/r/ABCDEF/host?k=short')); assert.equal(r.status,400);
const key='k'.repeat(24);
r = await room.fetch(req('/r/ABCDEF/host?k='+key)); assert.equal(r.status,101);
const host = all[0];
// wrong key rejected
r = await room.fetch(req('/r/ABCDEF/host?k='+'z'.repeat(24))); assert.equal(r.status,403);
// client joins
r = await room.fetch(req('/r/ABCDEF/c')); assert.equal(r.status,101);
const c1 = all[1];
const open = JSON.parse(host.sent[0]); assert.equal(open.k,'open'); const id=open.c;
// client -> host
await room.webSocketMessage(c1,'frame1');
assert.deepEqual(JSON.parse(host.sent[1]),{k:'msg',c:id,d:'frame1'});
// host -> client
await room.webSocketMessage(host, JSON.stringify({k:'msg',c:id,d:'reply'}));
assert.deepEqual(c1.sent,['reply']);
// host kick
await room.webSocketMessage(host, JSON.stringify({k:'kick',c:id}));
assert.ok(c1.closed);
// client close notifies host
r = await room.fetch(req('/r/ABCDEF/c')); const c2=all[2]; const id2=JSON.parse(host.sent.at(-1)).c;
await room.webSocketClose(c2,1000,'',true);
assert.deepEqual(JSON.parse(host.sent.at(-1)),{k:'close',c:id2});
// host replaced does not kick clients
r = await room.fetch(req('/r/ABCDEF/c')); const c3=all[3];
r = await room.fetch(req('/r/ABCDEF/host?k='+key)); assert.equal(r.status,101);
const host2 = all[4];
await room.webSocketClose(host,4000,'replaced',true);
assert.equal(c3.closed,null);
// real host drop kicks clients
await room.webSocketClose(host2,1006,'',false);
assert.ok(c3.closed);
// bye clears
r = await room.fetch(req('/r/ABCDEF/host?k='+key)); const host3=all.at(-1);
await room.webSocketMessage(host3, JSON.stringify({k:'bye'}));
assert.equal(store.size,0);
console.log('relay logic OK');
