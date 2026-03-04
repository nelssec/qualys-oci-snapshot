import { getObjectStorageClient } from '../shared/lib/oci-client';
import { initLogger, info, error } from '../shared/lib/logger';

/**
 * Download to Storage - Downloads artifacts (scanner binaries, configs)
 * from a source URL and stores them in OCI Object Storage.
 */

interface Input {
  sourceUrl: string;
  namespace: string;
  bucketName: string;
  objectName: string;
  headers?: Record<string, string>;
  region?: string;
}

async function handleRequest(input: Input): Promise<unknown> {
  const { sourceUrl, namespace, bucketName, objectName, headers = {}, region } = input;

  info('Downloading to storage', { sourceUrl, bucketName, objectName });

  // Download from source
  const response = await fetch(sourceUrl, { headers });

  if (!response.ok) {
    throw new Error(`Download failed: ${response.status} ${response.statusText}`);
  }

  const body = await response.arrayBuffer();
  const contentType = response.headers.get('content-type') || 'application/octet-stream';

  // Upload to Object Storage
  const client = getObjectStorageClient(region ? { region } : undefined);

  await client.putObject({
    namespaceName: namespace,
    bucketName,
    objectName,
    putObjectBody: Buffer.from(body),
    contentType,
    contentLength: body.byteLength,
  });

  info('Downloaded and stored', {
    objectName,
    size: body.byteLength,
    contentType,
  });

  return {
    success: true,
    objectName,
    size: body.byteLength,
    contentType,
  };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('download-to-storage', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('download-to-storage failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
