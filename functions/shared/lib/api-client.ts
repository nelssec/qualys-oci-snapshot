import { getSecret } from './vault-client';
import { VAULT } from './constants';
import { info, error } from './logger';
import type { QflowRequest, QflowResponse } from './types';

const qflowEndpoint = process.env.QFLOW_ENDPOINT || '';

export async function callQflowApi(request: QflowRequest): Promise<QflowResponse> {
  const token = await getSecret(VAULT.SECRET_NAME_QTOKEN);
  const tokenParts = token.split('.');
  const apiKey = tokenParts.length >= 3 ? tokenParts[2] : token;

  const url = `${qflowEndpoint}${request.path}`;

  try {
    const response = await fetch(url, {
      method: request.method,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
        ...request.headers,
      },
      body: request.body ? JSON.stringify(request.body) : undefined,
    });

    const responseHeaders: Record<string, string> = {};
    response.headers.forEach((value, key) => {
      responseHeaders[key] = value;
    });

    const body = await response.json().catch(() => ({}));

    info('qflow API call success', {
      method: request.method,
      path: request.path,
      statusCode: response.status,
    });

    return {
      statusCode: response.status,
      body,
      headers: responseHeaders,
    };
  } catch (e: unknown) {
    const err = e as Error;
    error('qflow API call failed', {
      method: request.method,
      path: request.path,
      error: err.message,
    });
    throw e;
  }
}

export async function registerWithQflow(
  tenancyId: string,
  compartmentId: string,
  region: string,
): Promise<QflowResponse> {
  return callQflowApi({
    method: 'POST',
    path: '/api/v1/oci/register',
    body: {
      tenancyId,
      compartmentId,
      region,
      provider: 'OCI',
    },
  });
}

export async function sendScanResults(
  resourceId: string,
  scanType: string,
  results: unknown,
): Promise<QflowResponse> {
  return callQflowApi({
    method: 'POST',
    path: '/api/v1/oci/scan-results',
    body: {
      resourceId,
      scanType,
      results,
      timestamp: new Date().toISOString(),
    },
  });
}

export async function notifyTaskComplete(
  taskId: string,
  status: string,
  details?: Record<string, unknown>,
): Promise<QflowResponse> {
  return callQflowApi({
    method: 'POST',
    path: '/api/v1/oci/task-complete',
    body: {
      taskId,
      status,
      details,
      timestamp: new Date().toISOString(),
    },
  });
}
