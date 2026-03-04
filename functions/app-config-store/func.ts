import * as nosqlClient from '../shared/lib/nosql-client';
import { NOSQL_TABLES } from '../shared/lib/constants';
import { initLogger, info, error } from '../shared/lib/logger';
import type { AppConfigEntry } from '../shared/lib/types';

interface Input {
  operation: 'get' | 'put' | 'delete' | 'list';
  configId?: string;
  configType?: string;
  configValue?: string;
  idx?: number;
}

async function handleRequest(input: Input): Promise<unknown> {
  const tableName = NOSQL_TABLES.APP_CONFIG;
  info('app-config-store invoked', { operation: input.operation, configId: input.configId });

  switch (input.operation) {
    case 'get': {
      if (input.configId && input.idx !== undefined) {
        return { config: await nosqlClient.getItem(tableName, { configId: input.configId, idx: input.idx }) };
      }
      // Get all entries for a configId
      const items = await nosqlClient.query(
        tableName,
        `SELECT * FROM ${tableName} WHERE configId = $configId ORDER BY idx`,
        { configId: input.configId },
      );
      // Reassemble multi-part config
      const fullValue = items.map((item) => (item as any).configValue || '').join('');
      return { configId: input.configId, configValue: fullValue, parts: items.length };
    }

    case 'put': {
      const value = input.configValue || '';
      // Split large configs into chunks (NoSQL row size limit)
      const chunkSize = 400_000; // ~400KB per row to stay within limits
      const chunks = [];
      for (let i = 0; i < value.length; i += chunkSize) {
        chunks.push(value.slice(i, i + chunkSize));
      }

      for (let idx = 0; idx < chunks.length; idx++) {
        const entry: AppConfigEntry = {
          configId: input.configId!,
          idx,
          configValue: chunks[idx],
          configType: input.configType || 'SCAN_CONFIG',
          updatedAt: new Date().toISOString(),
        };
        await nosqlClient.putItem(tableName, entry as unknown as Record<string, unknown>);
      }

      // Clean up old chunks if the new value has fewer parts
      const existing = await nosqlClient.query(
        tableName,
        `SELECT idx FROM ${tableName} WHERE configId = $configId AND idx >= $startIdx`,
        { configId: input.configId, startIdx: chunks.length },
      );
      for (const old of existing) {
        await nosqlClient.deleteItem(tableName, { configId: input.configId, idx: (old as any).idx });
      }

      return { success: true, parts: chunks.length };
    }

    case 'delete': {
      const items = await nosqlClient.query(
        tableName,
        `SELECT idx FROM ${tableName} WHERE configId = $configId`,
        { configId: input.configId },
      );
      for (const item of items) {
        await nosqlClient.deleteItem(tableName, { configId: input.configId, idx: (item as any).idx });
      }
      return { success: true, deleted: items.length };
    }

    case 'list': {
      const items = await nosqlClient.query(
        tableName,
        input.configType
          ? `SELECT DISTINCT configId, configType FROM ${tableName} WHERE configType = $configType`
          : `SELECT DISTINCT configId, configType FROM ${tableName}`,
        input.configType ? { configType: input.configType } : undefined,
      );
      return { configs: items };
    }

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
  initLogger('app-config-store', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('app-config-store failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
