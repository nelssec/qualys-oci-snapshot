import { getComputeClient } from '../shared/lib/oci-client';
import { TAGS } from '../shared/lib/constants';
import { initLogger, info, warn, error } from '../shared/lib/logger';

/**
 * Image Cleanup - Manages scanner image lifecycle.
 * Removes old scanner custom images when new versions are deployed.
 */

interface Input {
  compartmentId: string;
  region?: string;
  keepLatest?: number;
  dryRun?: boolean;
}

async function handleRequest(input: Input): Promise<unknown> {
  const { compartmentId, region, keepLatest = 2, dryRun = false } = input;

  info('Image cleanup started', { compartmentId, keepLatest, dryRun });

  const computeClient = getComputeClient(region ? { region } : undefined);

  // List all scanner custom images
  const response = await computeClient.listImages({
    compartmentId,
    lifecycleState: 'AVAILABLE' as any,
  });

  const scannerImages = (response.items || [])
    .filter((img: any) =>
      img.freeformTags?.[TAGS.APP_TAG_KEY] === TAGS.APP_TAG_VALUE
    )
    .sort((a: any, b: any) =>
      new Date(b.timeCreated).getTime() - new Date(a.timeCreated).getTime()
    );

  info('Found scanner images', { total: scannerImages.length });

  // Keep the N latest, delete the rest
  const toDelete = scannerImages.slice(keepLatest);
  const deleted: string[] = [];

  for (const img of toDelete) {
    const image = img as any;
    if (dryRun) {
      info('Would delete image (dry run)', { imageId: image.id, displayName: image.displayName });
    } else {
      try {
        await computeClient.deleteImage({ imageId: image.id });
        deleted.push(image.id);
        info('Image deleted', { imageId: image.id, displayName: image.displayName });
      } catch (e: unknown) {
        const err = e as Error;
        warn('Failed to delete image', { imageId: image.id, error: err.message });
      }
    }
  }

  return {
    totalImages: scannerImages.length,
    kept: Math.min(keepLatest, scannerImages.length),
    deleted: deleted.length,
    deletedIds: deleted,
    dryRun,
  };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('image-cleanup', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('image-cleanup failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
