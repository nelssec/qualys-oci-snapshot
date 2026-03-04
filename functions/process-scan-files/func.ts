import { getObjectStorageClient } from '../shared/lib/oci-client';
import * as nosqlClient from '../shared/lib/nosql-client';
import { NOSQL_TABLES } from '../shared/lib/constants';
import { initLogger, info, error } from '../shared/lib/logger';

/**
 * Process Scan Files - Parses scan results from Object Storage.
 * Reads the scanner output files, parses them, and stores structured results.
 */

interface Input {
  resourceId: string;
  scanType: string;
  bucketName: string;
  objectPrefix: string;
  namespace: string;
  region: string;
}

async function handleRequest(input: Input): Promise<unknown> {
  const { resourceId, scanType, bucketName, objectPrefix, namespace, region } = input;

  info('Processing scan files', { resourceId, scanType, bucketName, objectPrefix });

  const client = getObjectStorageClient({ region });

  // List objects in the scan results prefix
  const listResponse = await client.listObjects({
    namespaceName: namespace,
    bucketName,
    prefix: objectPrefix,
  });

  const objects = listResponse.listObjects?.objects || [];
  info('Found scan result files', { count: objects.length });

  const results: unknown[] = [];

  for (const obj of objects) {
    if (!obj.name) continue;

    const getResponse = await client.getObject({
      namespaceName: namespace,
      bucketName,
      objectName: obj.name,
    });

    // Read the stream
    const chunks: Buffer[] = [];
    const stream = getResponse.value as NodeJS.ReadableStream;
    for await (const chunk of stream) {
      chunks.push(Buffer.from(chunk));
    }
    const content = Buffer.concat(chunks).toString('utf-8');

    try {
      const parsed = JSON.parse(content);
      results.push(parsed);
    } catch {
      // Non-JSON files (logs, etc.)
      results.push({ file: obj.name, content: content.slice(0, 10000) });
    }
  }

  // Update scan status
  await nosqlClient.putItem(NOSQL_TABLES.SCAN_STATUS, {
    ResourceId: resourceId,
    ScanType: scanType,
    status: 'COMPLETED',
    scanEndTime: new Date().toISOString(),
  }, { ifPresent: true });

  info('Scan files processed', { resourceId, scanType, fileCount: results.length });

  return {
    resourceId,
    scanType,
    fileCount: results.length,
    results,
  };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('process-scan-files', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('process-scan-files failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
