# Unity Guardian Scripts

Proof-of-concept scripts demonstrating how guardians in a VRChat world can
communicate via the `LilybearOpsBus`. They are designed to receive messages
relayed from the Serafina Discord bot.

## Usage

1. In a VCC-compatible Unity project, create an empty GameObject and attach
   `LilybearOpsBus` to act as the scene's whisper router.
2. Add `LilybearController` to another empty GameObject. This represents the
   operations hub that can broadcast to all guardians.
3. For each guardian (e.g. Athena, Serafina, ShadowFlowers), create an empty
   GameObject and attach the corresponding `*Guardian` script.
4. Optionally, place a `TextMesh` in the scene and assign it to
   `ShadowFlowersGuardian.BlessingText` to visualize blessings.
5. Press Play and invoke `Test Whisper` from the `LilybearController`
   context menu to verify cross-guardian messaging.

When the Serafina Discord bot receives `!whisper <guardian> <message>` in the
configured guardian channel, it forwards the message to the Unity bridge service
(`UNITY_BRIDGE_URL`), which then calls `LilybearOpsBus.Say` with the provided
guardian and message.

Place the C# scripts under `Assets/GameDinVR/Scripts` inside your Unity project.
