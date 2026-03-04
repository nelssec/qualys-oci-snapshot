import {
  getComputeClient,
  getBlockstorageClient,
  getObjectStorageClient,
  getVirtualNetworkClient,
} from '../shared/lib/oci-client';
import { initLogger, info, error } from '../shared/lib/logger';
import type { OciSdkRequest, OciSdkResponse, FunctionContext } from '../shared/lib/types';

/**
 * Generic OCI SDK proxy function.
 * Accepts a service name, operation, and parameters, and executes the corresponding
 * OCI SDK call using Resource Principal authentication.
 *
 * This allows qflow to invoke any OCI API operation without needing a dedicated function.
 */

interface Input {
  service: string;
  operation: string;
  region?: string;
  params: Record<string, unknown>;
}

async function handleRequest(input: Input): Promise<OciSdkResponse> {
  const { service, operation, region, params } = input;
  const opts = region ? { region } : undefined;

  info('SDK wrapper invoked', { service, operation, region });

  try {
    let result: unknown;

    switch (service) {
      case 'compute': {
        const client = getComputeClient(opts);
        result = await (client as any)[operation](params);
        break;
      }
      case 'blockstorage': {
        const client = getBlockstorageClient(opts);
        result = await (client as any)[operation](params);
        break;
      }
      case 'objectstorage': {
        const client = getObjectStorageClient(opts);
        result = await (client as any)[operation](params);
        break;
      }
      case 'virtualnetwork': {
        const client = getVirtualNetworkClient(opts);
        result = await (client as any)[operation](params);
        break;
      }
      default:
        throw new Error(`Unsupported service: ${service}`);
    }

    return {
      statusCode: 200,
      data: result,
      opcRequestId: (result as any)?.opcRequestId || '',
    };
  } catch (e: unknown) {
    const err = e as Error;
    error('SDK wrapper error', { service, operation, error: err.message });
    return {
      statusCode: (e as any)?.statusCode || 500,
      data: { error: err.message },
      opcRequestId: (e as any)?.opcRequestId || '',
    };
  }
}

// OCI Functions entry point
async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('oci-sdk-wrapper', process.env.FN_CALL_ID || '');

  const result = await handleRequest(input);
  process.stdout.write(JSON.stringify(result));
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
