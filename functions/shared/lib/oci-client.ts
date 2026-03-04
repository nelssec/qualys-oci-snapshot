import * as common from 'oci-common';
import * as core from 'oci-core';
import * as nosql from 'oci-nosql';
import * as queue from 'oci-queue';
import * as vault from 'oci-vault';
import * as secrets from 'oci-secrets';
import * as kms from 'oci-keymanagement';
import * as objectstorage from 'oci-objectstorage';
import * as functions from 'oci-functions';
import * as identity from 'oci-identity';
import { info, error } from './logger';

let authProvider: common.AuthenticationDetailsProvider | null = null;

function getAuthProvider(): common.AuthenticationDetailsProvider {
  if (authProvider) return authProvider;

  try {
    authProvider = new common.ResourcePrincipalAuthenticationDetailsProvider();
    info('Initialized Resource Principal authentication');
  } catch (e) {
    // Fallback for local development
    authProvider = new common.ConfigFileAuthenticationDetailsProvider();
    info('Initialized Config File authentication (local dev)');
  }
  return authProvider;
}

export interface ClientOptions {
  region?: string;
  tenancyId?: string;
}

export function getComputeClient(opts?: ClientOptions): core.ComputeClient {
  const client = new core.ComputeClient({ authenticationDetailsProvider: getAuthProvider() });
  if (opts?.region) client.region = opts.region;
  return client;
}

export function getBlockstorageClient(opts?: ClientOptions): core.BlockstorageClient {
  const client = new core.BlockstorageClient({ authenticationDetailsProvider: getAuthProvider() });
  if (opts?.region) client.region = opts.region;
  return client;
}

export function getVirtualNetworkClient(opts?: ClientOptions): core.VirtualNetworkClient {
  const client = new core.VirtualNetworkClient({ authenticationDetailsProvider: getAuthProvider() });
  if (opts?.region) client.region = opts.region;
  return client;
}

export function getNosqlClient(opts?: ClientOptions): nosql.NosqlClient {
  const client = new nosql.NosqlClient({ authenticationDetailsProvider: getAuthProvider() });
  if (opts?.region) client.region = opts.region;
  return client;
}

export function getQueueClient(opts?: ClientOptions): queue.QueueClient {
  const client = new queue.QueueClient({ authenticationDetailsProvider: getAuthProvider() });
  if (opts?.region) client.region = opts.region;
  return client;
}

export function getVaultsClient(opts?: ClientOptions): vault.VaultsClient {
  const client = new vault.VaultsClient({ authenticationDetailsProvider: getAuthProvider() });
  if (opts?.region) client.region = opts.region;
  return client;
}

export function getSecretsClient(opts?: ClientOptions): secrets.SecretsClient {
  const client = new secrets.SecretsClient({ authenticationDetailsProvider: getAuthProvider() });
  if (opts?.region) client.region = opts.region;
  return client;
}

export function getKmsManagementClient(endpoint: string): kms.KmsManagementClient {
  return new kms.KmsManagementClient({ authenticationDetailsProvider: getAuthProvider() }, endpoint);
}

export function getKmsCryptoClient(endpoint: string): kms.KmsCryptoClient {
  return new kms.KmsCryptoClient({ authenticationDetailsProvider: getAuthProvider() }, endpoint);
}

export function getObjectStorageClient(opts?: ClientOptions): objectstorage.ObjectStorageClient {
  const client = new objectstorage.ObjectStorageClient({ authenticationDetailsProvider: getAuthProvider() });
  if (opts?.region) client.region = opts.region;
  return client;
}

export function getFunctionsManagementClient(opts?: ClientOptions): functions.FunctionsManagementClient {
  const client = new functions.FunctionsManagementClient({ authenticationDetailsProvider: getAuthProvider() });
  if (opts?.region) client.region = opts.region;
  return client;
}

export function getFunctionsInvokeClient(endpoint: string): functions.FunctionsInvokeClient {
  return new functions.FunctionsInvokeClient({ authenticationDetailsProvider: getAuthProvider() }, endpoint);
}

export function getIdentityClient(opts?: ClientOptions): identity.IdentityClient {
  const client = new identity.IdentityClient({ authenticationDetailsProvider: getAuthProvider() });
  if (opts?.region) client.region = opts.region;
  return client;
}

export function getTenancyId(): string {
  const provider = getAuthProvider();
  if (provider instanceof common.ResourcePrincipalAuthenticationDetailsProvider) {
    return process.env.OCI_RESOURCE_PRINCIPAL_RPT_ENDPOINT
      ? extractTenancyFromRpt()
      : process.env.SCANNING_TENANCY_ID || '';
  }
  return process.env.SCANNING_TENANCY_ID || '';
}

function extractTenancyFromRpt(): string {
  // In Resource Principal v2.1+, the tenancy is available from the claims
  return process.env.SCANNING_TENANCY_ID || '';
}
