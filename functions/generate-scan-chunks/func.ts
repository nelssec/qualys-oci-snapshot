import { SCAN_TYPES, PLATFORMS } from '../shared/lib/constants';
import { chunkArray } from '../shared/lib/data-formatter';
import { initLogger, info } from '../shared/lib/logger';

/**
 * Generate Scan Chunks - Batches scan types by platform.
 * Produces chunks of work items for parallel processing.
 */

interface Input {
  scanConfig: {
    swcaEnabled: string;
    secretEnabled: string;
    scannerPlatforms: string[];
  };
  resourceCount: number;
  chunkSize?: number;
}

interface ScanChunk {
  scanType: string;
  platform: string;
  chunkIndex: number;
  totalChunks: number;
}

async function handleRequest(input: Input): Promise<unknown> {
  const { scanConfig, resourceCount, chunkSize = 10 } = input;
  const chunks: ScanChunk[] = [];

  // Determine active scan types
  const activeScanTypes = [SCAN_TYPES.VULN]; // Always enabled
  if (scanConfig.swcaEnabled === 'Enabled') {
    activeScanTypes.push(SCAN_TYPES.SWCA);
  }
  if (scanConfig.secretEnabled === 'Enabled') {
    activeScanTypes.push(SCAN_TYPES.SECRET);
  }

  const platforms = scanConfig.scannerPlatforms || [PLATFORMS.LINUX, PLATFORMS.WINDOWS];
  const totalResourceChunks = Math.ceil(resourceCount / chunkSize);

  for (const scanType of activeScanTypes) {
    for (const platform of platforms) {
      for (let i = 0; i < totalResourceChunks; i++) {
        chunks.push({
          scanType,
          platform,
          chunkIndex: i,
          totalChunks: totalResourceChunks,
        });
      }
    }
  }

  info('Generated scan chunks', {
    scanTypes: activeScanTypes,
    platforms,
    totalChunks: chunks.length,
    resourceCount,
  });

  return { chunks, totalChunks: chunks.length };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('generate-scan-chunks', process.env.FN_CALL_ID || '');

  const result = await handleRequest(input);
  process.stdout.write(JSON.stringify(result));
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
