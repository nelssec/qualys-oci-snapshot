import { getObjectStorageClient } from '../shared/lib/oci-client';
import { TAGS } from '../shared/lib/constants';
import { initLogger, info, error } from '../shared/lib/logger';

/**
 * Create Bucket - Regional bucket provisioning.
 * Creates Object Storage buckets for scan data in specific regions.
 */

interface Input {
  bucketName: string;
  namespace: string;
  compartmentId: string;
  region: string;
  autoTiering?: boolean;
  retentionDays?: number;
}

async function handleRequest(input: Input): Promise<unknown> {
  const { bucketName, namespace, compartmentId, region, autoTiering = true } = input;

  info('Creating bucket', { bucketName, region });

  const client = getObjectStorageClient({ region });

  try {
    // Check if bucket already exists
    await client.getBucket({
      namespaceName: namespace,
      bucketName,
    });
    info('Bucket already exists', { bucketName });
    return { success: true, bucketName, created: false };
  } catch {
    // Bucket doesn't exist, create it
  }

  await client.createBucket({
    namespaceName: namespace,
    createBucketDetails: {
      name: bucketName,
      compartmentId,
      storageTier: 'Standard' as any,
      publicAccessType: 'NoPublicAccess' as any,
      autoTiering: autoTiering ? 'InfrequentAccess' as any : 'Disabled' as any,
      versioning: 'Disabled' as any,
      freeformTags: {
        [TAGS.APP_TAG_KEY]: TAGS.APP_TAG_VALUE,
      },
    },
  });

  info('Bucket created', { bucketName, region });
  return { success: true, bucketName, created: true };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('create-bucket', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('create-bucket failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
