import * as nosqlClient from '../shared/lib/nosql-client';
import { sendMessage } from '../shared/lib/queue-client';
import { NOSQL_TABLES, DEFAULT_TTL_DAYS } from '../shared/lib/constants';
import { initLogger, info, error } from '../shared/lib/logger';
import { v4 as uuidv4 } from 'uuid';
import type { DiscoveryTask, AppConfigEntry, ScanConfig } from '../shared/lib/types';

/**
 * Discovery Scheduler - Creates periodic discovery tasks for all configured
 * regions and target tenancies. Invoked by qflow on the configured interval.
 */

interface Input {
  targetTenancies: Array<{ tenancyId: string; compartmentId?: string }>;
  regions?: string[];
  forceRediscovery?: boolean;
}

async function handleRequest(input: Input): Promise<unknown> {
  const { targetTenancies, forceRediscovery } = input;

  // Load scan config to get regions
  const configItems = await nosqlClient.query(
    NOSQL_TABLES.APP_CONFIG,
    `SELECT * FROM ${NOSQL_TABLES.APP_CONFIG} WHERE configId = 'scan-config'`,
  );
  const configValue = configItems.map((c: any) => c.configValue || '').join('');
  const scanConfig: Partial<ScanConfig> = configValue ? JSON.parse(configValue) : {};

  const regions = input.regions || scanConfig.regions?.split(',') || [];
  const now = new Date();
  const ttl = Math.floor(now.getTime() / 1000) + DEFAULT_TTL_DAYS * 86400;
  const tasks: DiscoveryTask[] = [];

  info('Scheduling discovery', {
    tenancyCount: targetTenancies.length,
    regionCount: regions.length,
    forceRediscovery,
  });

  for (const target of targetTenancies) {
    for (const region of regions) {
      // Check if there's already a pending/in-progress task
      if (!forceRediscovery) {
        const existing = await nosqlClient.query(
          NOSQL_TABLES.DISCOVERY_TASK,
          `SELECT TaskId FROM ${NOSQL_TABLES.DISCOVERY_TASK} WHERE taskStatus IN ('PENDING', 'IN_PROGRESS') AND tenancyId = $tenancyId AND region = $region AND taskType = 'SCHEDULED'`,
          { tenancyId: target.tenancyId, region },
        );
        if (existing.length > 0) {
          info('Skipping - existing task found', { tenancyId: target.tenancyId, region });
          continue;
        }
      }

      const task: DiscoveryTask = {
        TaskId: uuidv4(),
        taskType: 'SCHEDULED',
        taskStatus: 'PENDING',
        region,
        tenancyId: target.tenancyId,
        targetCompartmentId: target.compartmentId,
        createdAt: now.toISOString(),
        updatedAt: now.toISOString(),
        resourceCount: 0,
        ExpireAt: ttl,
      };

      await nosqlClient.putItem(NOSQL_TABLES.DISCOVERY_TASK, task as unknown as Record<string, unknown>);

      await sendMessage(process.env.DISCOVERY_TASKS_QUEUE_ID || '', {
        taskId: task.TaskId,
        taskType: task.taskType,
        tenancyId: target.tenancyId,
        compartmentId: target.compartmentId,
        region,
      });

      tasks.push(task);
    }
  }

  info('Discovery scheduling complete', { tasksCreated: tasks.length });
  return { tasksCreated: tasks.length, taskIds: tasks.map((t) => t.TaskId) };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('discovery-scheduler', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('discovery-scheduler failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
