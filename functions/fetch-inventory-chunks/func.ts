import * as nosqlClient from '../shared/lib/nosql-client';
import { NOSQL_TABLES } from '../shared/lib/constants';
import { initLogger, info } from '../shared/lib/logger';
import type { ResourceInventoryItem } from '../shared/lib/types';

/**
 * Fetch Inventory Chunks - Queries NoSQL for scan candidates
 * based on region, platform, and priority. Returns paginated results.
 */

interface Input {
  region: string;
  platform: string;
  chunkIndex: number;
  chunkSize: number;
  scanSamplingEnabled?: boolean;
  samplingGroup?: string;
}

async function handleRequest(input: Input): Promise<unknown> {
  const { region, platform, chunkIndex, chunkSize, scanSamplingEnabled, samplingGroup } = input;
  const offset = chunkIndex * chunkSize;

  info('Fetching inventory chunk', { region, platform, chunkIndex, chunkSize });

  let statement: string;
  let variables: Record<string, unknown>;

  if (scanSamplingEnabled && samplingGroup) {
    statement = `SELECT * FROM ${NOSQL_TABLES.RESOURCE_INVENTORY} WHERE region = $region AND platform = $platform AND state = 'RUNNING' AND scanSamplingGroup = $samplingGroup ORDER BY scanPriority LIMIT $limit OFFSET $offset`;
    variables = { region, platform, samplingGroup, limit: chunkSize, offset };
  } else {
    statement = `SELECT * FROM ${NOSQL_TABLES.RESOURCE_INVENTORY} WHERE region = $region AND platform = $platform AND state = 'RUNNING' ORDER BY scanPriority LIMIT $limit OFFSET $offset`;
    variables = { region, platform, limit: chunkSize, offset };
  }

  const items = await nosqlClient.query(NOSQL_TABLES.RESOURCE_INVENTORY, statement, variables);

  info('Inventory chunk fetched', { count: items.length, region, platform });

  return {
    resources: items,
    count: items.length,
    chunkIndex,
    hasMore: items.length === chunkSize,
  };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('fetch-inventory-chunks', process.env.FN_CALL_ID || '');

  const result = await handleRequest(input);
  process.stdout.write(JSON.stringify(result));
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
