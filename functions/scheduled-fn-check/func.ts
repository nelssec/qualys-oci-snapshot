import * as nosqlClient from '../shared/lib/nosql-client';
import { NOSQL_TABLES } from '../shared/lib/constants';
import { initLogger, info, warn } from '../shared/lib/logger';

/**
 * Scheduled Function Check - Monitors running scan operations and
 * detects stale/stuck executions. Reports status to qflow.
 */

interface Input {
  maxAgeMinutes?: number;
}

interface StaleResource {
  resourceId: string;
  scanType: string;
  status: string;
  scanStartTime: string;
  ageMinutes: number;
}

async function handleRequest(input: Input): Promise<unknown> {
  const maxAgeMinutes = input.maxAgeMinutes || 120; // 2 hours default
  const now = new Date();

  info('Checking for stale executions', { maxAgeMinutes });

  // Find in-progress scans
  const activeScans = await nosqlClient.query(
    NOSQL_TABLES.SCAN_STATUS,
    `SELECT * FROM ${NOSQL_TABLES.SCAN_STATUS} WHERE status IN ('BACKING_UP', 'COPYING', 'SCANNING')`,
  );

  const staleResources: StaleResource[] = [];

  for (const scan of activeScans) {
    const s = scan as any;
    if (s.scanStartTime) {
      const startTime = new Date(s.scanStartTime);
      const ageMinutes = (now.getTime() - startTime.getTime()) / (1000 * 60);

      if (ageMinutes > maxAgeMinutes) {
        staleResources.push({
          resourceId: s.ResourceId,
          scanType: s.ScanType,
          status: s.status,
          scanStartTime: s.scanStartTime,
          ageMinutes: Math.round(ageMinutes),
        });
      }
    }
  }

  if (staleResources.length > 0) {
    warn('Found stale executions', { count: staleResources.length });
  }

  // Check for stale discovery tasks
  const activeTasks = await nosqlClient.query(
    NOSQL_TABLES.DISCOVERY_TASK,
    `SELECT * FROM ${NOSQL_TABLES.DISCOVERY_TASK} WHERE taskStatus = 'IN_PROGRESS'`,
  );

  const staleTasks: unknown[] = [];
  for (const task of activeTasks) {
    const t = task as any;
    if (t.updatedAt) {
      const updatedTime = new Date(t.updatedAt);
      const ageMinutes = (now.getTime() - updatedTime.getTime()) / (1000 * 60);
      if (ageMinutes > maxAgeMinutes) {
        staleTasks.push({
          taskId: t.TaskId,
          taskType: t.taskType,
          ageMinutes: Math.round(ageMinutes),
        });
      }
    }
  }

  info('Execution check complete', {
    activeScans: activeScans.length,
    staleScans: staleResources.length,
    activeTasks: activeTasks.length,
    staleTasks: staleTasks.length,
  });

  return {
    activeScans: activeScans.length,
    staleScans: staleResources,
    activeTasks: activeTasks.length,
    staleTasks,
  };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('scheduled-fn-check', process.env.FN_CALL_ID || '');

  const result = await handleRequest(input);
  process.stdout.write(JSON.stringify(result));
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
