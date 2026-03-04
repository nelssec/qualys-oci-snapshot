import { getComputeClient } from '../shared/lib/oci-client';
import { SCANNER_PORT } from '../shared/lib/constants';
import { initLogger, info, error } from '../shared/lib/logger';

/**
 * Proxy Instance - Proxies HTTP requests from the VCN to scanner instances.
 * Used by qflow to communicate with scanner instances over port 8000.
 */

interface Input {
  instanceId: string;
  method: string;
  path: string;
  body?: unknown;
  region?: string;
}

async function handleRequest(input: Input): Promise<unknown> {
  const { instanceId, method, path, body, region } = input;

  info('Proxying to scanner instance', { instanceId, method, path });

  // Get instance private IP
  const computeClient = getComputeClient(region ? { region } : undefined);
  const vnicAttachments = await computeClient.listVnicAttachments({
    compartmentId: process.env.COMPARTMENT_ID || '',
    instanceId,
  });

  const vnicId = vnicAttachments.items?.[0]?.vnicId;
  if (!vnicId) {
    throw new Error(`No VNIC found for instance ${instanceId}`);
  }

  // Get VNIC details for private IP
  const { getVirtualNetworkClient } = await import('../shared/lib/oci-client');
  const networkClient = getVirtualNetworkClient(region ? { region } : undefined);
  const vnic = await networkClient.getVnic({ vnicId });
  const privateIp = vnic.vnic?.privateIp;

  if (!privateIp) {
    throw new Error(`No private IP for instance ${instanceId}`);
  }

  // Proxy the request to the scanner instance
  const url = `http://${privateIp}:${SCANNER_PORT}${path}`;

  const response = await fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });

  const responseBody = await response.text();

  info('Proxy response', {
    instanceId,
    statusCode: response.status,
  });

  return {
    statusCode: response.status,
    body: responseBody,
    headers: Object.fromEntries(response.headers.entries()),
  };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('proxy-instance', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('proxy-instance failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message, statusCode: 502 }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
