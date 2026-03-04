import * as nosqlClient from '../shared/lib/nosql-client';
import { sendMessage } from '../shared/lib/queue-client';
import { NOSQL_TABLES, DEFAULT_TTL_DAYS } from '../shared/lib/constants';
import { initLogger, info, error } from '../shared/lib/logger';
import { v4 as uuidv4 } from 'uuid';
import type { DiscoveryTask } from '../shared/lib/types';

/**
 * Image Discovery Scheduler - Creates tasks for custom image scanning.
 * Similar to discovery-scheduler but focused on custom images (AMI equivalent).
 */

interface Input {
  targetTenancies: Array<{ tenancyId: string; compartmentId?: string }>;
  regions?: string[];
}

async function handleRequest(input: Input): Promise<unknown> {
  const { targetTenancies, regions = [] } = input;
  const now = new Date();
  const ttl = Math.floor(now.getTime() / 1000) + DEFAULT_TTL_DAYS * 86400;
  const tasks: DiscoveryTask[] = [];

  info('Scheduling image discovery', {
    tenancyCount: targetTenancies.length,
    regionCount: regions.length,
  });

  for (const target of targetTenancies) {
    for (const region of regions) {
      const existing = await nosqlClient.query(
        NOSQL_TABLES.DISCOVERY_TASK,
        `SELECT TaskId FROM ${NOSQL_TABLES.DISCOVERY_TASK} WHERE taskStatus IN ('PENDING', 'IN_PROGRESS') AND tenancyId = $tenancyId AND region = $region AND taskType = 'IMAGE'`,
        { tenancyId: target.tenancyId, region },
      );

      if (existing.length > 0) {
        info('Skipping - existing image task found', { tenancyId: target.tenancyId, region });
        continue;
      }

      const task: DiscoveryTask = {
        TaskId: uuidv4(),
        taskType: 'IMAGE',
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
        taskType: 'IMAGE',
        tenancyId: target.tenancyId,
        compartmentId: target.compartmentId,
        region,
      });

      tasks.push(task);
    }
  }

  info('Image discovery scheduling complete', { tasksCreated: tasks.length });
  return { tasksCreated: tasks.length, taskIds: tasks.map((t) => t.TaskId) };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('image-discovery-scheduler', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('image-discovery-scheduler failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
