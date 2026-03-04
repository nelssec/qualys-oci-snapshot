import { TAGS, SCANNER_PORT } from '../shared/lib/constants';
import { initLogger, info } from '../shared/lib/logger';
import type { ScannerLaunchParams, ResourceInventoryItem } from '../shared/lib/types';

/**
 * Generate Scan Params - Builds scanner instance launch parameters.
 * Creates the shape, image, network, and metadata configuration for
 * a scanner compute instance.
 */

interface Input {
  resource: ResourceInventoryItem;
  scanType: string;
  volumeIds: string[];
  scannerImageId: string;
  subnetId: string;
  nsgIds: string[];
  compartmentId: string;
  availabilityDomain: string;
  shape?: string;
  scannerConfig?: Record<string, string>;
}

async function handleRequest(input: Input): Promise<ScannerLaunchParams> {
  const {
    resource,
    scanType,
    volumeIds,
    scannerImageId,
    subnetId,
    nsgIds,
    compartmentId,
    availabilityDomain,
    shape = 'VM.Standard.E4.Flex',
    scannerConfig = {},
  } = input;

  info('Generating scan params', {
    resourceId: resource.resourceId,
    scanType,
    volumeCount: volumeIds.length,
  });

  const displayName = `scanner-${scanType.toLowerCase()}-${resource.resourceId.split('.').pop()}-${Date.now()}`;

  const metadata: Record<string, string> = {
    scan_type: scanType,
    resource_id: resource.resourceId,
    tenancy_id: resource.tenancyId,
    region: resource.region,
    platform: resource.platform,
    volume_ids: JSON.stringify(volumeIds),
    scanner_port: String(SCANNER_PORT),
    results_bucket: process.env.SCAN_DATA_BUCKET || `snapshot-scan-data-${resource.region}`,
    results_prefix: `scan-results/${resource.resourceId}/${scanType}/${new Date().toISOString().split('T')[0]}/`,
    qflow_endpoint: process.env.QFLOW_ENDPOINT || '',
    ...scannerConfig,
  };

  // Add cloud-init user data for scanner bootstrap
  const userData = generateCloudInit(scanType, resource.platform, volumeIds);
  metadata['user_data'] = Buffer.from(userData).toString('base64');

  const params: ScannerLaunchParams = {
    compartmentId,
    availabilityDomain,
    shape,
    imageId: scannerImageId,
    subnetId,
    nsgIds,
    displayName,
    volumeIds,
    scanType,
    resourceId: resource.resourceId,
    metadata,
    freeformTags: {
      [TAGS.APP_TAG_KEY]: TAGS.APP_TAG_VALUE,
      ScanType: scanType,
      TargetResource: resource.resourceId,
    },
  };

  return params;
}

function generateCloudInit(scanType: string, platform: string, volumeIds: string[]): string {
  if (platform === 'WINDOWS') {
    return `<powershell>
# Scanner bootstrap - Windows
$ErrorActionPreference = "Stop"
$scanType = "${scanType}"
$volumeIds = '${JSON.stringify(volumeIds)}'

# Wait for volumes to be attached
Start-Sleep -Seconds 30

# Mount volumes and run scan
# Scanner binary is pre-installed in the custom image
& "C:\\scanner\\run-scan.ps1" -ScanType $scanType -VolumeIds $volumeIds
</powershell>`;
  }

  return `#!/bin/bash
set -euo pipefail

SCAN_TYPE="${scanType}"
VOLUME_IDS='${JSON.stringify(volumeIds)}'

# Wait for volumes to attach
sleep 30

# Discover and mount attached volumes
DEVICE_INDEX=0
for DEVICE in /dev/oracleoci/oraclevd*; do
  if [ -b "$DEVICE" ]; then
    MOUNT_POINT="/mnt/scan/vol_$DEVICE_INDEX"
    mkdir -p "$MOUNT_POINT"
    mount -o ro "$DEVICE" "$MOUNT_POINT" 2>/dev/null || true
    DEVICE_INDEX=$((DEVICE_INDEX + 1))
  fi
done

# Run scanner (pre-installed in custom image)
/opt/scanner/run-scan.sh --type "$SCAN_TYPE" --mount-path /mnt/scan

# Upload results to Object Storage
/opt/scanner/upload-results.sh
`;
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const input: Input = JSON.parse(inputData || '{}');
  initLogger('generate-scan-params', process.env.FN_CALL_ID || '');

  const result = await handleRequest(input);
  process.stdout.write(JSON.stringify(result));
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
