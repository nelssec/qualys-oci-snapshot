import * as nosqlClient from '../shared/lib/nosql-client';
import { initLogger, info, error } from '../shared/lib/logger';

interface Input {
  operation: 'get' | 'put' | 'delete' | 'query' | 'batchWrite';
  tableName: string;
  key?: Record<string, unknown>;
  item?: Record<string, unknown>;
  items?: Record<string, unknown>[];
  statement?: string;
  variables?: Record<string, unknown>;
  options?: { ifAbsent?: boolean; ifPresent?: boolean };
}

async function handleRequest(input: Input): Promise<unknown> {
  const { operation, tableName } = input;
  info('NoSQL wrapper invoked', { operation, tableName });

  switch (operation) {
    case 'get':
      return { item: await nosqlClient.getItem(tableName, input.key!) };
    case 'put':
      await nosqlClient.putItem(tableName, input.item!, input.options);
      return { success: true };
    case 'delete':
      await nosqlClient.deleteItem(tableName, input.key!);
      return { success: true };
    case 'query':
      return { items: await nosqlClient.query(tableName, input.statement!, input.variables) };
    case 'batchWrite':
      await nosqlClient.batchWrite(tableName, input.items!);
      return { success: true };
    default:
      throw new Error(`Unsupported operation: ${operation}`);
  }
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('nosql-wrapper', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('nosql-wrapper failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
