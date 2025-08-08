import fetch from 'node-fetch';

interface HandshakePayload {
  name: string;
  version: string;
  timestamp: string;
  capabilities: string[];
}

/**
 * Perform handshake with sibling nodes defined in MESH_NODES.
 * Each node should expose POST /mesh/handshake.
 */
export async function performMeshHandshake(): Promise<void> {
  const nodes = (process.env.MESH_NODES || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  if (!nodes.length) return;

  const payload: HandshakePayload = {
    name: process.env.NODE_NAME || 'serafina',
    version: process.env.npm_package_version || '0.0.0',
    timestamp: new Date().toISOString(),
    capabilities: ['discord-router', 'nightly-report'],
  };

  for (const base of nodes) {
    const url = base.replace(/\/$/, '') + '/mesh/handshake';
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      if (res.ok) {
        console.log(`mesh handshake ok with ${base}`);
      } else {
        console.warn(`mesh handshake failed with ${base}: ${res.status}`);
      }
    } catch (err) {
      console.warn(`mesh handshake error with ${base}`, err);
    }
  }
}
