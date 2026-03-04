import { getNosqlClient } from './oci-client';
import * as nosql from 'oci-nosql';
import { info, error, warn } from './logger';

const compartmentId = process.env.COMPARTMENT_ID || '';

export interface QueryOptions {
  tableName: string;
  compartmentId?: string;
  consistency?: 'EVENTUAL' | 'ABSOLUTE';
}

export interface PutOptions {
  tableName: string;
  compartmentId?: string;
  ifAbsent?: boolean;
  ifPresent?: boolean;
  ttlDays?: number;
}

export async function getItem(
  tableName: string,
  key: Record<string, unknown>,
): Promise<Record<string, unknown> | null> {
  const client = getNosqlClient();
  try {
    const response = await client.getRow({
      tableNameOrId: tableName,
      compartmentId,
      key: Object.entries(key).map(([column, value]) => ({
        column,
        value: JSON.stringify(value),
      })),
    });
    return response.row?.value ? JSON.parse(JSON.stringify(response.row.value)) : null;
  } catch (e: unknown) {
    const err = e as Error;
    error('NoSQL getItem failed', { tableName, key, error: err.message });
    throw e;
  }
}

export async function putItem(
  tableName: string,
  item: Record<string, unknown>,
  options?: { ifAbsent?: boolean; ifPresent?: boolean },
): Promise<void> {
  const client = getNosqlClient();
  try {
    await client.updateRow({
      tableNameOrId: tableName,
      compartmentId,
      updateRowDetails: {
        value: item,
        compartmentId,
        option: options?.ifAbsent
          ? nosql.models.UpdateRowDetails.Option.IfAbsent
          : options?.ifPresent
            ? nosql.models.UpdateRowDetails.Option.IfPresent
            : undefined,
      },
    });
    info('NoSQL putItem success', { tableName });
  } catch (e: unknown) {
    const err = e as Error;
    error('NoSQL putItem failed', { tableName, error: err.message });
    throw e;
  }
}

export async function deleteItem(
  tableName: string,
  key: Record<string, unknown>,
): Promise<void> {
  const client = getNosqlClient();
  try {
    await client.deleteRow({
      tableNameOrId: tableName,
      compartmentId,
      key: Object.entries(key).map(([column, value]) => ({
        column,
        value: JSON.stringify(value),
      })),
    });
    info('NoSQL deleteItem success', { tableName });
  } catch (e: unknown) {
    const err = e as Error;
    error('NoSQL deleteItem failed', { tableName, key, error: err.message });
    throw e;
  }
}

export async function query(
  tableName: string,
  statement: string,
  variables?: Record<string, unknown>,
): Promise<Record<string, unknown>[]> {
  const client = getNosqlClient();
  const results: Record<string, unknown>[] = [];

  try {
    let page: string | undefined;
    do {
      const response = await client.query({
        queryDetails: {
          compartmentId,
          statement,
          isGetQueryPlan: false,
          variables: variables
            ? Object.entries(variables).map(([name, value]) => ({
                name,
                value: { type: typeof value === 'number' ? 'NUMBER' : 'STRING', value: String(value) },
              }))
            : undefined,
        },
        ...(page ? { page } : {}),
      });
      if (response.queryResultCollection?.items) {
        results.push(...response.queryResultCollection.items as Record<string, unknown>[]);
      }
      page = response.opcNextPage;
    } while (page);

    info('NoSQL query success', { tableName, resultCount: results.length });
    return results;
  } catch (e: unknown) {
    const err = e as Error;
    error('NoSQL query failed', { tableName, statement, error: err.message });
    throw e;
  }
}

export async function batchWrite(
  tableName: string,
  items: Record<string, unknown>[],
): Promise<void> {
  const client = getNosqlClient();

  // OCI NoSQL batch limit is typically 25 items
  const batchSize = 25;
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    try {
      // Use individual puts for each item in the batch
      await Promise.all(batch.map((item) => putItem(tableName, item)));
      info('NoSQL batchWrite chunk success', { tableName, chunkSize: batch.length });
    } catch (e: unknown) {
      const err = e as Error;
      error('NoSQL batchWrite chunk failed', { tableName, error: err.message });
      throw e;
    }
  }
}
