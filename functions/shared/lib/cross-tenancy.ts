import * as common from 'oci-common';
import { getComputeClient, getBlockstorageClient } from './oci-client';
import { info, error } from './logger';

/**
 * Cross-tenancy operations use the same Resource Principal authentication,
 * but the endorsed/admit policies at the root compartment level allow
 * the scanning tenancy's dynamic group to operate in the target tenancy.
 *
 * The key mechanism:
 * - Scanning tenancy has "endorse" policies for its dynamic group
 * - Target tenancy has "admit" policies accepting that dynamic group
 * - API calls specify the target tenancy's compartment ID
 */

export async function listInstancesCrossTenancy(
  targetTenancyId: string,
  compartmentId: string,
  region: string,
): Promise<unknown[]> {
  const client = getComputeClient({ region });
  const instances: unknown[] = [];

  try {
    let page: string | undefined;
    do {
      const response = await client.listInstances({
        compartmentId,
        lifecycleState: 'RUNNING' as any,
        ...(page ? { page } : {}),
      });
      if (response.items) instances.push(...response.items);
      page = response.opcNextPage;
    } while (page);

    info('Cross-tenancy listInstances success', {
      targetTenancyId,
      region,
      count: instances.length,
    });
    return instances;
  } catch (e: unknown) {
    const err = e as Error;
    error('Cross-tenancy listInstances failed', {
      targetTenancyId,
      region,
      error: err.message,
    });
    throw e;
  }
}

export async function listVolumeAttachmentsCrossTenancy(
  compartmentId: string,
  instanceId: string,
  region: string,
): Promise<unknown[]> {
  const client = getComputeClient({ region });
  const attachments: unknown[] = [];

  try {
    let page: string | undefined;
    do {
      const response = await client.listVolumeAttachments({
        compartmentId,
        instanceId,
        ...(page ? { page } : {}),
      });
      if (response.items) attachments.push(...response.items);
      page = response.opcNextPage;
    } while (page);

    info('Cross-tenancy listVolumeAttachments success', { instanceId, region, count: attachments.length });
    return attachments;
  } catch (e: unknown) {
    const err = e as Error;
    error('Cross-tenancy listVolumeAttachments failed', { instanceId, region, error: err.message });
    throw e;
  }
}

export async function listBootVolumeAttachmentsCrossTenancy(
  compartmentId: string,
  instanceId: string,
  availabilityDomain: string,
  region: string,
): Promise<unknown[]> {
  const client = getComputeClient({ region });
  const attachments: unknown[] = [];

  try {
    let page: string | undefined;
    do {
      const response = await client.listBootVolumeAttachments({
        compartmentId,
        availabilityDomain,
        instanceId,
        ...(page ? { page } : {}),
      });
      if (response.items) attachments.push(...response.items);
      page = response.opcNextPage;
    } while (page);

    info('Cross-tenancy listBootVolumeAttachments success', { instanceId, region, count: attachments.length });
    return attachments;
  } catch (e: unknown) {
    const err = e as Error;
    error('Cross-tenancy listBootVolumeAttachments failed', { instanceId, region, error: err.message });
    throw e;
  }
}

export async function createVolumeBackupCrossTenancy(
  volumeId: string,
  displayName: string,
  region: string,
  volumeType: 'boot' | 'block',
): Promise<unknown> {
  const client = getBlockstorageClient({ region });

  try {
    if (volumeType === 'boot') {
      const response = await client.createBootVolumeBackup({
        createBootVolumeBackupDetails: {
          bootVolumeId: volumeId,
          displayName,
          type: 'FULL' as any,
          freeformTags: { App: 'snapshot-scanner' },
        },
      });
      info('Cross-tenancy createBootVolumeBackup success', { volumeId, region });
      return response.bootVolumeBackup;
    } else {
      const response = await client.createVolumeBackup({
        createVolumeBackupDetails: {
          volumeId,
          displayName,
          type: 'FULL' as any,
          freeformTags: { App: 'snapshot-scanner' },
        },
      });
      info('Cross-tenancy createVolumeBackup success', { volumeId, region });
      return response.volumeBackup;
    }
  } catch (e: unknown) {
    const err = e as Error;
    error('Cross-tenancy createVolumeBackup failed', { volumeId, region, error: err.message });
    throw e;
  }
}

export async function copyVolumeBackupCrossTenancy(
  backupId: string,
  sourceRegion: string,
  destinationRegion: string,
  kmsKeyId: string,
  displayName: string,
): Promise<unknown> {
  const client = getBlockstorageClient({ region: sourceRegion });

  try {
    const response = await client.copyVolumeBackup({
      volumeBackupId: backupId,
      copyVolumeBackupDetails: {
        destinationRegion,
        displayName,
        kmsKeyId,
      },
    });
    info('Cross-tenancy copyVolumeBackup success', { backupId, sourceRegion, destinationRegion });
    return response.volumeBackup;
  } catch (e: unknown) {
    const err = e as Error;
    error('Cross-tenancy copyVolumeBackup failed', { backupId, error: err.message });
    throw e;
  }
}
