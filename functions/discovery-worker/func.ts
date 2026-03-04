import {
  listInstancesCrossTenancy,
  listVolumeAttachmentsCrossTenancy,
  listBootVolumeAttachmentsCrossTenancy,
} from '../shared/lib/cross-tenancy';
import { formatInstanceToInventory, formatVolumeAttachment } from '../shared/lib/data-formatter';
import { shouldIncludeResource, shouldIncludeVolume } from '../shared/lib/tag-filter';
import * as nosqlClient from '../shared/lib/nosql-client';
import { NOSQL_TABLES } from '../shared/lib/constants';
import { initLogger, info, error, warn } from '../shared/lib/logger';
import type { VolumeInfo, TagsConfig, ResourceInventoryItem } from '../shared/lib/types';

/**
 * Discovery Worker - Performs cross-tenancy instance discovery.
 * Enumerates running instances, their volume attachments, and populates
 * the resource_inventory NoSQL table.
 */

interface Input {
  taskId: string;
  tenancyId: string;
  region: string;
  compartmentId?: string;
  instanceIds?: string[];
  tagsConfig?: TagsConfig;
}

async function handleRequest(input: Input): Promise<unknown> {
  const { taskId, tenancyId, region, compartmentId, instanceIds, tagsConfig } = input;
  const targetCompartment = compartmentId || tenancyId;

  info('Discovery worker started', { taskId, tenancyId, region });

  // Update task status to IN_PROGRESS
  await nosqlClient.putItem(NOSQL_TABLES.DISCOVERY_TASK, {
    TaskId: taskId,
    taskStatus: 'IN_PROGRESS',
    updatedAt: new Date().toISOString(),
  }, { ifPresent: true });

  try {
    // List all running instances in the target tenancy/compartment
    const instances = await listInstancesCrossTenancy(tenancyId, targetCompartment, region);
    info('Discovered instances', { count: instances.length, region });

    // Filter to specific instance IDs if provided (event-based discovery)
    let filteredInstances = instances;
    if (instanceIds && instanceIds.length > 0) {
      filteredInstances = instances.filter((inst: any) => instanceIds.includes(inst.id));
      info('Filtered to specific instances', { requested: instanceIds.length, found: filteredInstances.length });
    }

    // Apply tag filters
    const defaultTagsConfig: TagsConfig = tagsConfig || {
      mustHaveTags: '',
      anyInListTags: '',
      noneInTheList: '',
      noneOnVolume: '',
      qualysTags: 'App=snapshot-scanner',
    };

    let inventoryCount = 0;

    for (const instance of filteredInstances) {
      const inst = instance as Record<string, unknown>;

      // Apply tag filter on instance
      if (!shouldIncludeResource(inst as any, defaultTagsConfig)) {
        continue;
      }

      // Discover boot volume attachments
      const bootAttachments = await listBootVolumeAttachmentsCrossTenancy(
        targetCompartment,
        inst.id as string,
        inst.availabilityDomain as string,
        region,
      );

      // Discover block volume attachments
      const volumeAttachments = await listVolumeAttachmentsCrossTenancy(
        targetCompartment,
        inst.id as string,
        region,
      );

      // Format volume info
      const volumes: VolumeInfo[] = [];

      for (const ba of bootAttachments) {
        const vol = formatVolumeAttachment(ba as Record<string, unknown>, 'boot');
        if (shouldIncludeVolume(vol, defaultTagsConfig)) {
          volumes.push(vol);
        }
      }

      for (const va of volumeAttachments) {
        const vol = formatVolumeAttachment(va as Record<string, unknown>, 'block');
        if (shouldIncludeVolume(vol, defaultTagsConfig)) {
          volumes.push(vol);
        }
      }

      // Skip instances where all volumes are excluded
      if (volumes.length === 0) {
        warn('Skipping instance - all volumes excluded by tag filter', { instanceId: inst.id });
        continue;
      }

      // Format and store inventory record
      const inventoryItem = formatInstanceToInventory(inst, volumes, tenancyId);

      // Check if resource already exists (update instead of create)
      const existing = await nosqlClient.query(
        NOSQL_TABLES.RESOURCE_INVENTORY,
        `SELECT UID FROM ${NOSQL_TABLES.RESOURCE_INVENTORY} WHERE resourceId = $resourceId`,
        { resourceId: inst.id },
      );

      if (existing.length > 0) {
        inventoryItem.UID = (existing[0] as any).UID;
      }

      await nosqlClient.putItem(
        NOSQL_TABLES.RESOURCE_INVENTORY,
        inventoryItem as unknown as Record<string, unknown>,
      );

      inventoryCount++;
    }

    // Update task as completed
    await nosqlClient.putItem(NOSQL_TABLES.DISCOVERY_TASK, {
      TaskId: taskId,
      taskStatus: 'COMPLETED',
      resourceCount: inventoryCount,
      updatedAt: new Date().toISOString(),
    }, { ifPresent: true });

    info('Discovery complete', { taskId, inventoryCount });
    return { taskId, status: 'COMPLETED', resourceCount: inventoryCount };

  } catch (e: unknown) {
    const err = e as Error;
    error('Discovery failed', { taskId, error: err.message });

    await nosqlClient.putItem(NOSQL_TABLES.DISCOVERY_TASK, {
      TaskId: taskId,
      taskStatus: 'FAILED',
      updatedAt: new Date().toISOString(),
    }, { ifPresent: true });

    throw e;
  }
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('discovery-worker', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
