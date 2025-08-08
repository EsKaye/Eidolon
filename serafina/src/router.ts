import 'dotenv/config';
import fetch from 'node-fetch';
import {
  Client,
  GatewayIntentBits,
  REST,
  Routes,
  SlashCommandBuilder,
} from 'discord.js';
import {
  scheduleNightlyCouncilReport,
  sendCouncilReport,
} from './nightlyReport.js';
import { performMeshHandshake } from './meshHandshake.js';

// Allowed guardians are defined in env for security. Comparison is case-insensitive
// but original casing is preserved when relaying to the Unity bridge so that
// guardian scripts can match their `GuardianName` exactly.
const allowedGuardians = (process.env.GUARDIAN_NAMES || '')
  .split(',')
  .map((s) => s.trim().toLowerCase())
  .filter(Boolean);

// Discord client with message intent so guardians can be triggered
export const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
  ],
});

// ------------------------------
// Slash command registration
// ------------------------------
const commands = [
  new SlashCommandBuilder()
    .setName('council-report-now')
    .setDescription('Dispatch the nightly council report immediately'),
];

async function registerCommands(): Promise<void> {
  const rest = new REST({ version: '10' }).setToken(
    process.env.DISCORD_TOKEN as string,
  );
  await rest.put(
    Routes.applicationGuildCommands(
      process.env.CLIENT_ID as string,
      process.env.GUILD_ID as string,
    ),
    { body: commands.map((c) => c.toJSON()) },
  );
}

// ------------------------------
// Utility to relay guardian messages to Unity bridge service
// ------------------------------
async function relayToUnity(guardian: string, message: string): Promise<void> {
  const url = process.env.UNITY_BRIDGE_URL;
  if (!url) {
    console.warn('UNITY_BRIDGE_URL not set; skipping relay');
    return;
  }
  try {
    await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ guardian, message }),
    });
  } catch (err) {
    console.error('relay error', err);
  }
}

// ------------------------------
// Handle Discord messages intended for guardians.
// Format: !whisper <guardian> <message>
// ------------------------------
client.on('messageCreate', (msg) => {
  if (msg.author.bot) return;
  if (msg.channel.id !== process.env.CHN_GUARDIANS) return;

  const match = msg.content.match(/^!whisper\s+(\w+)\s+(.+)/i);
  if (!match) return;

  const [, guardianRaw, text] = match;
  const guardian = guardianRaw.trim();
  // Respect whitelist when provided to avoid arbitrary guardian names
  if (
    allowedGuardians.length &&
    !allowedGuardians.includes(guardian.toLowerCase())
  ) {
    console.warn(`guardian ${guardian} not in whitelist; ignoring`);
    return;
  }
  void relayToUnity(guardian, text);
});

// ------------------------------
// Slash command handling
// ------------------------------
client.on('interactionCreate', async (interaction) => {
  if (!interaction.isChatInputCommand()) return;

  if (interaction.commandName === 'council-report-now') {
    await interaction.deferReply({ ephemeral: true });
    await sendCouncilReport(client);
    await interaction.editReply('Council report dispatched.');
  }
});

// ------------------------------
// Startup
// ------------------------------
client.once('ready', () => {
  console.log('Serafina online as', client.user?.tag);
  scheduleNightlyCouncilReport(client);
  void performMeshHandshake();
});

await registerCommands();
await client.login(process.env.DISCORD_TOKEN);
