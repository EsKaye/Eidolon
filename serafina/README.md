# Serafina Bot Extensions

This directory hosts experimental add-ons for the Serafina Discord bot.

## Features
- Scheduled **nightly council report** posted at 08:00 UTC.
- Manual slash command `/council-report-now` for on-demand reports.
- Guardian relay: messages like `!whisper Athena <msg>` in the guardian
  channel are forwarded to the Unity bridge service. Only guardians listed
  in `GUARDIAN_NAMES` will be relayed, preventing arbitrary targets.
- Mesh handshake: on startup, Serafina pings sibling services listed in
  `MESH_NODES` to announce presence and capabilities.

## Setup
1. Copy `.env.example` to `.env` and fill in secrets like `DISCORD_TOKEN`, `CLIENT_ID`, and channel IDs.
2. Install dependencies: `npm install`.
3. Start the bot: `npm start` (uses [`tsx`](https://github.com/esbuild-kit/tsx) and requires Node >=18).

To participate in the cross-repo mesh, ensure `MESH_NODES` and `NODE_NAME`
are set in your `.env`.

The bot assumes a companion Unity scene running the `LilybearOpsBus`
with guardians listening for relay payloads.
