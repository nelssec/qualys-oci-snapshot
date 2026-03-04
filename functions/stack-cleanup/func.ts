import { getComputeClient, getBlockstorageClient } from '../shared/lib/oci-client';
import * as nosqlClient from '../shared/lib/nosql-client';
import { NOSQL_TABLES, TAGS } from '../shared/lib/constants';
import { initLogger, info, warn, error } from '../shared/lib/logger';

/**
 * Stack Cleanup - Cleans up scanner resources after scan completion.
 * Terminates scanner instances, deletes volumes, and removes backups.
 */

interface Input {
  resourceId: string;
  scanType: string;
  region?: string;
  scannerInstanceId?: string;
  volumeIds?: string[];
  backupIds?: string[];
  copyBackupIds?: string[];
}

async function handleRequest(input: Input): Promise<unknown> {
  const { resourceId, scanType, region, scannerInstanceId, volumeIds = [], backupIds = [], copyBackupIds = [] } = input;
  const opts = region ? { region } : undefined;

  info('Starting cleanup', { resourceId, scanType, scannerInstanceId });

  const results = {
    instanceTerminated: false,
    volumesDeleted: 0,
    backupsDeleted: 0,
    errors: [] as string[],
  };

  // Terminate scanner instance
  if (scannerInstanceId) {
    try {
      const computeClient = getComputeClient(opts);
      await computeClient.terminateInstance({
        instanceId: scannerInstanceId,
        preserveBootVolume: false,
      });
      results.instanceTerminated = true;
      info('Scanner instance terminated', { scannerInstanceId });
    } catch (e: unknown) {
      const err = e as Error;
      warn('Failed to terminate instance', { scannerInstanceId, error: err.message });
      results.errors.push(`Instance ${scannerInstanceId}: ${err.message}`);
    }
  }

  // Delete volumes created in scanning tenancy
  const blockClient = getBlockstorageClient(opts);
  for (const volumeId of volumeIds) {
    try {
      await blockClient.deleteVolume({ volumeId });
      results.volumesDeleted++;
      info('Volume deleted', { volumeId });
    } catch (e: unknown) {
      const err = e as Error;
      warn('Failed to delete volume', { volumeId, error: err.message });
      results.errors.push(`Volume ${volumeId}: ${err.message}`);
    }
  }

  // Delete backup copies in scanning tenancy
  for (const backupId of copyBackupIds) {
    try {
      await blockClient.deleteVolumeBackup({ volumeBackupId: backupId });
      results.backupsDeleted++;
      info('Backup copy deleted', { backupId });
    } catch (e: unknown) {
      const err = e as Error;
      warn('Failed to delete backup copy', { backupId, error: err.message });
      results.errors.push(`Backup ${backupId}: ${err.message}`);
    }
  }

  // Delete original backups in target tenancy
  for (const backupId of backupIds) {
    try {
      await blockClient.deleteVolumeBackup({ volumeBackupId: backupId });
      results.backupsDeleted++;
      info('Original backup deleted', { backupId });
    } catch (e: unknown) {
      const err = e as Error;
      warn('Failed to delete original backup', { backupId, error: err.message });
      results.errors.push(`Backup ${backupId}: ${err.message}`);
    }
  }

  // Update scan status
  const finalStatus = results.errors.length === 0 ? 'COMPLETED' : 'CLEANUP';
  await nosqlClient.putItem(NOSQL_TABLES.SCAN_STATUS, {
    ResourceId: resourceId,
    ScanType: scanType,
    status: finalStatus,
  }, { ifPresent: true });

  info('Cleanup complete', results);
  return results;
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('stack-cleanup', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('stack-cleanup failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
