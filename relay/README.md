# CASE 007 online relay

A tiny Cloudflare Worker that lets phones play over the internet. It copies frames between the host and the players and never reads them.

## Deploy (free)

1. Make a free Cloudflare account.
2. Install Node.js (LTS).
3. In this folder:
   ```
   npm install
   npx wrangler login
   npx wrangler deploy
   ```
4. Wrangler prints a URL like `https://case007-relay.<name>.workers.dev`.
5. Put it in the app as `wss://case007-relay.<name>.workers.dev`: either in `lib/core/relay_config.dart` (`kRelayUrl`, for everyone who installs your build) or per phone in Settings > Online server.
6. Open the URL in a browser; it must say `CASE 007 relay OK`.

## Free plan limits

Durable Objects work on the Workers Free plan. Requests are capped per day (WebSocket messages count 1 per 20) and when the cap is hit the relay stops answering until 00:00 UTC. Check the current numbers at developers.cloudflare.com/durable-objects/platform/pricing.

## Safety notes

- Frames are signed (HMAC with the room code) but not encrypted. The relay operator can read them.
- The first host to open a room code stores a random secret; only a host with that secret can reconnect to the room.
- At most 12 sockets per room, 64 KB per player frame.
