import * as nosqlClient from '../shared/lib/nosql-client';
import { sendMessage } from '../shared/lib/queue-client';
import { NOSQL_TABLES, DEFAULT_TTL_DAYS } from '../shared/lib/constants';
import { initLogger, info, error } from '../shared/lib/logger';
import { v4 as uuidv4 } from 'uuid';
import type { DiscoveryTask } from '../shared/lib/types';

/**
 * On-Demand Scan - Initiates scanning for specific instances
 * on demand (outside of scheduled or event-based triggers).
 */

interface Input {
  tenancyId: string;
  region: string;
  instanceIds: string[];
  scanTypes?: string[];
  priority?: number;
}

async function handleRequest(input: Input): Promise<unknown> {
  const { tenancyId, region, instanceIds, scanTypes = ['VULN'], priority = 1 } = input;

  info('On-demand scan requested', {
    tenancyId,
    region,
    instanceCount: instanceIds.length,
    scanTypes,
  });

  const now = new Date();
  const ttl = Math.floor(now.getTime() / 1000) + DEFAULT_TTL_DAYS * 86400;

  // Create a discovery task for the specific instances
  const task: DiscoveryTask = {
    TaskId: uuidv4(),
    taskType: 'ON_DEMAND',
    taskStatus: 'PENDING',
    region,
    tenancyId,
    createdAt: now.toISOString(),
    updatedAt: now.toISOString(),
    instanceIds,
    resourceCount: instanceIds.length,
    ExpireAt: ttl,
  };

  await nosqlClient.putItem(NOSQL_TABLES.DISCOVERY_TASK, task as unknown as Record<string, unknown>);

  // Enqueue for processing with high priority
  await sendMessage(process.env.DISCOVERY_TASKS_QUEUE_ID || '', {
    taskId: task.TaskId,
    taskType: 'ON_DEMAND',
    tenancyId,
    region,
    instanceIds,
    scanTypes,
    priority,
  });

  info('On-demand scan task created', { taskId: task.TaskId });

  return {
    taskId: task.TaskId,
    status: 'PENDING',
    instanceCount: instanceIds.length,
    scanTypes,
  };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('on-demand-scan', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('on-demand-scan failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
