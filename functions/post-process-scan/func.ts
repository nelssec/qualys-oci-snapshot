import { sendScanResults } from '../shared/lib/api-client';
import * as nosqlClient from '../shared/lib/nosql-client';
import { NOSQL_TABLES } from '../shared/lib/constants';
import { initLogger, info, error } from '../shared/lib/logger';

/**
 * Post Process Scan - After scan files are processed, sends results
 * to qflow and triggers cleanup of scanner resources.
 */

interface Input {
  resourceId: string;
  scanType: string;
  results: unknown;
  scannerInstanceId?: string;
  volumeIds?: string[];
  backupIds?: string[];
}

async function handleRequest(input: Input): Promise<unknown> {
  const { resourceId, scanType, results, scannerInstanceId, volumeIds, backupIds } = input;

  info('Post-processing scan', { resourceId, scanType });

  // Send results to qflow
  const qflowResponse = await sendScanResults(resourceId, scanType, results);

  info('Results sent to qflow', {
    resourceId,
    scanType,
    statusCode: qflowResponse.statusCode,
  });

  // Update scan status to indicate cleanup is needed
  await nosqlClient.putItem(NOSQL_TABLES.SCAN_STATUS, {
    ResourceId: resourceId,
    ScanType: scanType,
    status: 'CLEANUP',
    scanEndTime: new Date().toISOString(),
  }, { ifPresent: true });

  return {
    resourceId,
    scanType,
    qflowStatusCode: qflowResponse.statusCode,
    cleanupRequired: {
      scannerInstanceId,
      volumeIds: volumeIds || [],
      backupIds: backupIds || [],
    },
  };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('post-process-scan', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('post-process-scan failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
