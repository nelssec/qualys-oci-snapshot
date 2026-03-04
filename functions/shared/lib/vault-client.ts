import { getSecretsClient, getVaultsClient } from './oci-client';
import { info, error } from './logger';

const compartmentId = process.env.COMPARTMENT_ID || '';
const vaultId = process.env.VAULT_ID || '';

// Cache secrets in memory for the lifetime of the function invocation
const secretCache = new Map<string, { value: string; expiresAt: number }>();
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

export async function getSecret(secretId: string): Promise<string> {
  const cached = secretCache.get(secretId);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.value;
  }

  const client = getSecretsClient();
  try {
    const response = await client.getSecretBundleByName({
      secretName: secretId,
      vaultId,
    });

    const content = response.secretBundle?.secretBundleContent;
    if (!content) throw new Error(`Secret ${secretId} has no content`);

    // Secret content is base64 encoded
    const value = Buffer.from(
      (content as { content: string }).content,
      'base64',
    ).toString('utf-8');

    secretCache.set(secretId, { value, expiresAt: Date.now() + CACHE_TTL_MS });
    info('Vault getSecret success', { secretId });
    return value;
  } catch (e: unknown) {
    const err = e as Error;
    error('Vault getSecret failed', { secretId, error: err.message });
    throw e;
  }
}

export async function createSecret(
  secretName: string,
  secretValue: string,
  description?: string,
): Promise<string> {
  const vaultsClient = getVaultsClient();
  try {
    const response = await vaultsClient.createSecret({
      createSecretDetails: {
        compartmentId,
        vaultId,
        secretName,
        description: description || `Secret for ${secretName}`,
        secretContent: {
          contentType: 'BASE64',
          content: Buffer.from(secretValue).toString('base64'),
        },
        keyId: process.env.MASTER_KEY_ID || '',
      },
    });
    info('Vault createSecret success', { secretName });
    return response.secret.id;
  } catch (e: unknown) {
    const err = e as Error;
    error('Vault createSecret failed', { secretName, error: err.message });
    throw e;
  }
}

export async function updateSecret(secretId: string, secretValue: string): Promise<void> {
  const vaultsClient = getVaultsClient();
  try {
    await vaultsClient.updateSecret({
      secretId,
      updateSecretDetails: {
        secretContent: {
          contentType: 'BASE64',
          content: Buffer.from(secretValue).toString('base64'),
        },
      },
    });
    secretCache.delete(secretId);
    info('Vault updateSecret success', { secretId });
  } catch (e: unknown) {
    const err = e as Error;
    error('Vault updateSecret failed', { secretId, error: err.message });
    throw e;
  }
}

export function clearSecretCache(): void {
  secretCache.clear();
}
