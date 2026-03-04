import { getFunctionsManagementClient, getObjectStorageClient } from '../shared/lib/oci-client';
import { initLogger, info, error } from '../shared/lib/logger';

/**
 * Update Function Code - Self-update mechanism. Downloads new function
 * container images from qflow/Object Storage and updates OCI Functions.
 */

interface Input {
  functionId?: string;
  functionName?: string;
  applicationId: string;
  newImage: string;
  region?: string;
}

async function handleRequest(input: Input): Promise<unknown> {
  const { functionId, functionName, applicationId, newImage, region } = input;

  info('Updating function code', { functionId, functionName, newImage });

  const fnClient = getFunctionsManagementClient(region ? { region } : undefined);

  let targetFunctionId = functionId;

  // If functionName provided instead of ID, look it up
  if (!targetFunctionId && functionName) {
    const functions = await fnClient.listFunctions({ applicationId });
    const fn = functions.items?.find((f: any) => f.displayName === functionName);
    if (!fn) {
      throw new Error(`Function not found: ${functionName}`);
    }
    targetFunctionId = (fn as any).id;
  }

  if (!targetFunctionId) {
    throw new Error('Either functionId or functionName is required');
  }

  // Update the function image
  await fnClient.updateFunction({
    functionId: targetFunctionId,
    updateFunctionDetails: {
      image: newImage,
    },
  });

  info('Function updated', { functionId: targetFunctionId, newImage });

  return {
    success: true,
    functionId: targetFunctionId,
    newImage,
  };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('update-function-code', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(input);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('update-function-code failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
