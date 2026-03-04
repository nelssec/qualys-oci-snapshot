import {
  formatInstanceToInventory,
  formatVolumeAttachment,
  createScanStatusRecord,
  chunkArray,
  generateBackupDisplayName,
} from '../shared/lib/data-formatter';
import { shouldIncludeResource, shouldIncludeVolume, filterResources } from '../shared/lib/tag-filter';
import { initLogger, info } from '../shared/lib/logger';
import type { TagsConfig, VolumeInfo } from '../shared/lib/types';

interface Input {
  operation: 'formatInstance' | 'formatVolume' | 'createScanStatus' | 'filterByTags' | 'chunk' | 'generateBackupName';
  instance?: Record<string, unknown>;
  volumes?: VolumeInfo[];
  tenancyId?: string;
  attachment?: Record<string, unknown>;
  volumeType?: 'boot' | 'block';
  resourceId?: string;
  scanType?: string;
  region?: string;
  platform?: 'LINUX' | 'WINDOWS';
  resources?: Array<Record<string, unknown>>;
  tagsConfig?: TagsConfig;
  array?: unknown[];
  chunkSize?: number;
}

async function handleRequest(input: Input): Promise<unknown> {
  info('data-formatter invoked', { operation: input.operation });

  switch (input.operation) {
    case 'formatInstance':
      return formatInstanceToInventory(input.instance!, input.volumes || [], input.tenancyId || '');
    case 'formatVolume':
      return formatVolumeAttachment(input.attachment!, input.volumeType || 'block');
    case 'createScanStatus':
      return createScanStatusRecord(input.resourceId!, input.scanType!, input.region!, input.platform!);
    case 'filterByTags':
      return { filtered: filterResources(input.resources || [], input.tagsConfig!) };
    case 'chunk':
      return { chunks: chunkArray(input.array || [], input.chunkSize || 10) };
    case 'generateBackupName':
      return { name: generateBackupDisplayName(input.resourceId!, input.volumeType!, input.scanType!) };
    default:
      throw new Error(`Unsupported operation: ${input.operation}`);
  }
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('data-formatter', process.env.FN_CALL_ID || '');

  const result = await handleRequest(input);
  process.stdout.write(JSON.stringify(result));
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
