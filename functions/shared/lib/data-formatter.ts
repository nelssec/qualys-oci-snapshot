import type { ResourceInventoryItem, VolumeInfo, ScanStatusRecord } from './types';
import { TAGS, DEFAULT_TTL_DAYS } from './constants';
import { info } from './logger';
import { v4 as uuidv4 } from 'uuid';

export function formatInstanceToInventory(
  instance: Record<string, unknown>,
  volumes: VolumeInfo[],
  tenancyId: string,
): ResourceInventoryItem {
  const now = new Date();
  const expiresAt = new Date(now.getTime() + DEFAULT_TTL_DAYS * 24 * 60 * 60 * 1000);

  return {
    UID: uuidv4(),
    resourceId: instance.id as string,
    resourceType: 'instance',
    tenancyId,
    compartmentId: instance.compartmentId as string,
    region: instance.region as string || '',
    availabilityDomain: instance.availabilityDomain as string,
    displayName: instance.displayName as string,
    state: instance.lifecycleState as string,
    platform: detectPlatform(instance),
    shape: instance.shape as string,
    imageId: (instance.sourceDetails as Record<string, unknown>)?.imageId as string || '',
    timeCreated: instance.timeCreated as string,
    freeformTags: (instance.freeformTags as Record<string, string>) || {},
    definedTags: (instance.definedTags as Record<string, Record<string, string>>) || {},
    volumes,
    scanPriority: calculatePriority(instance),
    lastDiscoveredAt: now.toISOString(),
    ExpiresAt: Math.floor(expiresAt.getTime() / 1000),
  };
}

export function formatVolumeAttachment(
  attachment: Record<string, unknown>,
  volumeType: 'boot' | 'block',
): VolumeInfo {
  return {
    volumeId: (attachment.bootVolumeId || attachment.volumeId) as string,
    volumeType,
    attachmentId: attachment.id as string,
    sizeInGBs: (attachment.sizeInGBs as number) || 0,
    availabilityDomain: attachment.availabilityDomain as string,
    isEncrypted: !!(attachment.kmsKeyId),
    kmsKeyId: attachment.kmsKeyId as string | undefined,
    freeformTags: (attachment.freeformTags as Record<string, string>) || {},
  };
}

export function createScanStatusRecord(
  resourceId: string,
  scanType: string,
  region: string,
  platform: 'LINUX' | 'WINDOWS',
): ScanStatusRecord {
  const now = new Date();
  const expiresAt = new Date(now.getTime() + DEFAULT_TTL_DAYS * 24 * 60 * 60 * 1000);

  return {
    ResourceId: resourceId,
    ScanType: scanType,
    region,
    platform,
    status: 'PENDING',
    backupIds: [],
    copyBackupIds: [],
    scannerVolumeIds: [],
    ExpiresAt: Math.floor(expiresAt.getTime() / 1000),
  };
}

function detectPlatform(instance: Record<string, unknown>): 'LINUX' | 'WINDOWS' {
  const metadata = instance.metadata as Record<string, string> | undefined;
  const displayName = (instance.displayName as string || '').toLowerCase();
  const imageId = ((instance.sourceDetails as Record<string, unknown>)?.imageId as string || '').toLowerCase();

  if (displayName.includes('windows') || imageId.includes('windows')) {
    return 'WINDOWS';
  }

  if (metadata?.['user_data']) {
    // Check for PowerShell indicators in user data
    const userData = Buffer.from(metadata['user_data'], 'base64').toString('utf-8');
    if (userData.includes('powershell') || userData.includes('cmd.exe')) {
      return 'WINDOWS';
    }
  }

  return 'LINUX';
}

function calculatePriority(instance: Record<string, unknown>): number {
  const tags = (instance.freeformTags as Record<string, string>) || {};

  // Higher priority for tagged instances
  if (tags['priority'] === 'high') return 1;
  if (tags['priority'] === 'medium') return 5;
  if (tags['priority'] === 'low') return 10;

  return 5; // Default priority
}

export function chunkArray<T>(array: T[], chunkSize: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < array.length; i += chunkSize) {
    chunks.push(array.slice(i, i + chunkSize));
  }
  return chunks;
}

export function generateBackupDisplayName(
  resourceId: string,
  volumeType: 'boot' | 'block',
  scanType: string,
): string {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  return `snapshot-${volumeType}-${scanType}-${resourceId.split('.').pop()}-${timestamp}`;
}
