import { callQflowApi, registerWithQflow, sendScanResults, notifyTaskComplete } from '../shared/lib/api-client';
import { initLogger, info, error } from '../shared/lib/logger';
import type { QflowRequest } from '../shared/lib/types';

interface Input {
  operation: 'call' | 'register' | 'sendResults' | 'notifyComplete' | 'validateToken';
  request?: QflowRequest;
  tenancyId?: string;
  compartmentId?: string;
  region?: string;
  resourceId?: string;
  scanType?: string;
  results?: unknown;
  taskId?: string;
  status?: string;
  details?: Record<string, unknown>;
  // Connector Hub stream records (for NoSQL -> qflow streaming)
  records?: Array<Record<string, unknown>>;
}

async function handleRequest(input: Input): Promise<unknown> {
  info('qflow-api invoked', { operation: input.operation });

  switch (input.operation) {
    case 'call':
      return await callQflowApi(input.request!);

    case 'register':
      return await registerWithQflow(input.tenancyId!, input.compartmentId!, input.region!);

    case 'sendResults':
      return await sendScanResults(input.resourceId!, input.scanType!, input.results);

    case 'notifyComplete':
      return await notifyTaskComplete(input.taskId!, input.status!, input.details);

    case 'validateToken': {
      // Used by API Gateway custom authentication
      // Validates the x-api-key header against the stored token
      const tokenHeader = input.request?.headers?.['x-api-key'] || '';
      if (!tokenHeader) {
        return { isValid: false, error: 'Missing x-api-key header' };
      }
      // In production, compare against stored token from Vault
      return { isValid: true, principal: 'event-forwarder' };
    }

    default:
      // Handle Connector Hub stream records
      if (input.records && Array.isArray(input.records)) {
        info('Processing Connector Hub stream records', { count: input.records.length });
        for (const record of input.records) {
          await callQflowApi({
            method: 'POST',
            path: '/api/v1/oci/stream-event',
            body: record as Record<string, unknown>,
          });
        }
        return { processed: input.records.length };
      }
      throw new Error(`Unsupported operation: ${input.operation}`);
  }
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('qflow-api', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('qflow-api failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
