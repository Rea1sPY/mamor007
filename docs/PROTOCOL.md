# Protocol

Transport: WebSocket on port 8765 (falls back up to 8785). Every frame is JSON `{b, g}` where `b` is the JSON body `{t, f, s, d}` (type, sender id, sequence, data) and `g` is HMAC-SHA256(roomCode, b).

Client to host: join, ready, chat, share, hyp, vote, ask, sample, lab, ping, leave. Host only: selectCase, genCase, start, advance, toLobby.
Host to client: welcome, lobby, intel, phase, shared, chat, progress, answer, samples, labres, error, closed, pong.

Discovery: UDP port 8799. Client broadcasts `C007?<h>` where h is a 10-hex hash of the room code; the host replies `C007!<h>:<tcpPort>`. Fallback: `GET /hello?h=<h>` on ports 8765 to 8767 returns `C007`. The room code itself is never sent in clear.

Interrogation: `ask {sid, topic, tone, arg}` with topic alibi, rel, money, saw, others, evidence and tone neutral, empathy, pressure, accuse. The answer goes only to the asker. `sample {sid}` asks for a fingerprint sample; `lab {print, sid}` compares a print with a sample and spends one lab request for the whole team.

Phases: lobby, briefing, investigation, hypothesis, voting, result. The host validates every transition and message; sequence numbers must increase; 10 messages per second per client; duplicate chat ids are dropped; one hypothesis and one vote per player. The verdict is the suspect with most votes; the case is won only if it is the real culprit.

Online relay: the host phone opens `wss://<relay>/r/<CODE>/host?k=<secret>`, players open `wss://<relay>/r/<CODE>/c`. Game frames are unchanged. Between relay and host they are wrapped in JSON envelopes: relay to host `{k:"open"|"msg"|"close", c:<connId>, d:<frame>}`, host to relay `{k:"msg"|"kick"|"ping"|"bye", c:<connId>, d:<frame>}`. The relay closes players with code 4001 when the host socket drops; players reconnect with their saved token exactly as on a LAN.
