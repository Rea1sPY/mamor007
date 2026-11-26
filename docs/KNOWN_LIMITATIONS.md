# Known limitations

- The full case file, including the solution, ships inside the APK. Technically skilled people can extract it. The host only sends each player their own evidence; the solution is sent to clients only at the result phase.
- No payload encryption. Messages are signed (HMAC-SHA256, key derived from the room code) which blocks injection and replay on a LAN, but traffic is readable on the network.
- Online play needs a deployed relay and its address. Frames are signed, not encrypted; the relay operator could read them. The free Cloudflare plan has a daily request cap, after which the relay stops answering until 00:00 UTC. LAN play does not depend on it.
- No host migration. If the host closes the app, the session ends for everyone.
- The host app must stay in the foreground; Android may suspend the server in the background. Clients reconnect for 90 seconds after a drop.
- A player who disconnects for more than 90 seconds is marked as left; the game continues without them.
- Late joiners are rejected after the game starts.
- Discovery needs a network that allows UDP broadcast or direct device-to-device traffic. Guest Wi-Fi with client isolation blocks it; use a phone hotspot instead.
- The interrogation AI is an offline rule engine, not a language model; it has a large but finite phrase set.
- Closed cases are remembered per phone only.
- Persian only. Pass-and-play on one device is not included.
- Icons are Material icons.
- Sound is nine short effects only; there is no background music.
- Notebook entries are stored per case id on the phone, are capped at 2000 characters, and are erased by "delete all data".
- No game timers: phases advance by player actions and host control.
