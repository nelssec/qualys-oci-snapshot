import * as nosqlClient from '../shared/lib/nosql-client';
import { sendMessage } from '../shared/lib/queue-client';
import { NOSQL_TABLES, QUEUES, DEFAULT_TTL_DAYS } from '../shared/lib/constants';
import { initLogger, info, error } from '../shared/lib/logger';
import { v4 as uuidv4 } from 'uuid';
import type { DiscoveryTask, EventLogEntry, OciResourceEvent } from '../shared/lib/types';

/**
 * Event Task Scheduler - Receives forwarded events from target tenancies
 * via API Gateway. Creates discovery tasks and event log entries.
 * Batches events into tasks based on the configured batch window.
 */

interface Input {
  source?: string;
  tenancyId?: string;
  event?: OciResourceEvent;
  forwardedAt?: string;
}

async function handleRequest(input: Input): Promise<unknown> {
  const { event, tenancyId } = input;

  if (!event || !tenancyId) {
    return { error: 'Missing event or tenancyId' };
  }

  info('Processing forwarded event', {
    eventType: event.eventType,
    resourceId: event.data?.resourceId,
    tenancyId,
  });

  const now = new Date();
  const ttl = Math.floor(now.getTime() / 1000) + DEFAULT_TTL_DAYS * 86400;

  // Log the event
  const eventLog: EventLogEntry = {
    UID: uuidv4(),
    instanceId: event.data?.resourceId || '',
    eventType: event.eventType,
    eventTime: event.eventTime,
    region: event.source || '',
    tenancyId,
    status: 'RECEIVED',
    details: event.data as unknown as Record<string, unknown>,
    ExpiresAt: ttl,
  };
  await nosqlClient.putItem(NOSQL_TABLES.EVENT_LOGS, eventLog as unknown as Record<string, unknown>);

  // Check for existing pending task for this region/tenancy
  const existingTasks = await nosqlClient.query(
    NOSQL_TABLES.DISCOVERY_TASK,
    `SELECT * FROM ${NOSQL_TABLES.DISCOVERY_TASK} WHERE taskStatus = 'PENDING' AND tenancyId = $tenancyId AND region = $region`,
    { tenancyId, region: event.source || '' },
  );

  if (existingTasks.length > 0) {
    // Append to existing task
    const task = existingTasks[0] as unknown as DiscoveryTask;
    const instanceIds = task.instanceIds || [];
    if (!instanceIds.includes(event.data?.resourceId)) {
      instanceIds.push(event.data?.resourceId);
    }
    await nosqlClient.putItem(NOSQL_TABLES.DISCOVERY_TASK, {
      ...task,
      instanceIds,
      resourceCount: instanceIds.length,
      updatedAt: now.toISOString(),
    } as unknown as Record<string, unknown>, { ifPresent: true });
    info('Appended to existing discovery task', { taskId: task.TaskId });
    return { taskId: task.TaskId, action: 'appended' };
  }

  // Create new discovery task
  const task: DiscoveryTask = {
    TaskId: uuidv4(),
    taskType: 'EVENT_BASED',
    taskStatus: 'PENDING',
    region: event.source || '',
    tenancyId,
    createdAt: now.toISOString(),
    updatedAt: now.toISOString(),
    instanceIds: [event.data?.resourceId],
    resourceCount: 1,
    ExpireAt: ttl,
  };

  await nosqlClient.putItem(NOSQL_TABLES.DISCOVERY_TASK, task as unknown as Record<string, unknown>);

  // Also enqueue for processing
  await sendMessage(process.env.DISCOVERY_TASKS_QUEUE_ID || '', {
    taskId: task.TaskId,
    taskType: task.taskType,
    tenancyId,
    region: event.source,
  });

  info('Created new discovery task', { taskId: task.TaskId });
  return { taskId: task.TaskId, action: 'created' };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('event-task-scheduler', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('event-task-scheduler failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
