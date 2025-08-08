import 'dotenv/config';
import fetch from 'node-fetch';
import cron from 'node-cron';
import {
  Client,
  EmbedBuilder,
  TextChannel,
} from 'discord.js';

// ------------------------------
// Utility to grab system health from MCP
// ------------------------------
async function getMcpStatus(): Promise<string> {
  try {
    const r = await fetch(`${process.env.MCP_URL}/ask-gemini`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt: 'Summarize system health in one sentence.' }),
    });
    const j = await r.json().catch(() => ({ response: '(no data)' }));
    return j.response || '(no data)';
  } catch {
    return '(MCP unreachable)';
  }
}

// ------------------------------
// Lightweight GitHub commit digest
// ------------------------------
async function getRepoDigest(repo: string): Promise<string> {
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const url = `https://api.github.com/repos/${repo}/commits?since=${encodeURIComponent(
    since,
  )}&per_page=5`;
  try {
    const r = await fetch(url, {
      headers: { Accept: 'application/vnd.github+json' },
    });
    if (!r.ok) return `• ${repo}: no recent commits`;
    const commits = (await r.json()) as any[];
    if (!commits.length) return `• ${repo}: 0 commits in last 24h`;
    const lines = commits.map(
      (c) =>
        `• ${repo}@${(c.sha || '').slice(0, 7)} — ${c.commit.message.split('\n')[0]}`,
    );
    return lines.join('\n');
  } catch {
    return `• ${repo}: (error fetching commits)`;
  }
}

// ------------------------------
// Build report embed used for both scheduled and manual dispatch
// ------------------------------
async function buildReportEmbed(): Promise<EmbedBuilder> {
  const mcp = await getMcpStatus();
  const repos = (process.env.NAV_REPOS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  const repoLines = repos.length
    ? (await Promise.all(repos.map(getRepoDigest))).join('\n')
    : '—';

  return new EmbedBuilder()
    .setTitle('🌙 Nightly Council Report')
    .setDescription('Summary of the last 24h across our realm.')
    .setColor(0x9b59b6)
    .addFields(
      { name: 'System Health (MCP)', value: mcp.slice(0, 1024) || '—' },
      { name: 'Recent Commits', value: repoLines.slice(0, 1024) || '—' },
    )
    .setFooter({ text: 'Reported by Lilybear' })
    .setTimestamp(new Date());
}

// ------------------------------
// Manual dispatch used by slash command
// ------------------------------
export async function sendCouncilReport(client: Client): Promise<void> {
  const ch = client.channels.cache.get(
    process.env.CHN_COUNCIL as string,
  ) as TextChannel | undefined;
  const embed = await buildReportEmbed();

  if (process.env.WH_LILYBEAR) {
    await fetch(process.env.WH_LILYBEAR, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ embeds: [embed.toJSON()] }),
    });
  } else if (ch) {
    await ch.send({ embeds: [embed] });
  }
}

// ------------------------------
// Scheduler setup invoked on bot start
// ------------------------------
export function scheduleNightlyCouncilReport(client: Client): void {
  cron.schedule(
    '0 8 * * *',
    () => {
      void sendCouncilReport(client);
    },
    { timezone: 'UTC' },
  );
}
