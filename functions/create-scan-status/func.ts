import * as nosqlClient from '../shared/lib/nosql-client';
import { createScanStatusRecord } from '../shared/lib/data-formatter';
import { NOSQL_TABLES } from '../shared/lib/constants';
import { initLogger, info, error } from '../shared/lib/logger';
import type { ScanStatusRecord } from '../shared/lib/types';

/**
 * Create Scan Status - Creates scan status records for resources
 * that are about to be scanned. One record per resource per scan type.
 */

interface Input {
  resources: Array<{
    resourceId: string;
    region: string;
    platform: 'LINUX' | 'WINDOWS';
  }>;
  scanTypes: string[];
}

async function handleRequest(input: Input): Promise<unknown> {
  const { resources, scanTypes } = input;
  const created: ScanStatusRecord[] = [];

  info('Creating scan status records', {
    resourceCount: resources.length,
    scanTypes,
  });

  for (const resource of resources) {
    for (const scanType of scanTypes) {
      // Check if already exists
      const existing = await nosqlClient.getItem(NOSQL_TABLES.SCAN_STATUS, {
        ResourceId: resource.resourceId,
        ScanType: scanType,
      });

      if (existing) {
        const status = (existing as any).status;
        if (['PENDING', 'BACKING_UP', 'COPYING', 'SCANNING'].includes(status)) {
          info('Skipping - scan already in progress', {
            resourceId: resource.resourceId,
            scanType,
            status,
          });
          continue;
        }
      }

      const record = createScanStatusRecord(
        resource.resourceId,
        scanType,
        resource.region,
        resource.platform,
      );

      await nosqlClient.putItem(
        NOSQL_TABLES.SCAN_STATUS,
        record as unknown as Record<string, unknown>,
      );

      created.push(record);
    }
  }

  info('Scan status records created', { count: created.length });
  return { created: created.length, records: created };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('create-scan-status', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('create-scan-status failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
