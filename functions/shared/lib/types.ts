// OCI resource types used across all functions

export interface OciResourceEvent {
  eventType: string;
  cloudEventsVersion: string;
  eventTypeVersion: string;
  source: string;
  eventId: string;
  eventTime: string;
  contentType: string;
  data: {
    compartmentId: string;
    compartmentName: string;
    resourceName: string;
    resourceId: string;
    availabilityDomain: string;
    freeformTags: Record<string, string>;
    definedTags: Record<string, Record<string, string>>;
    additionalDetails?: Record<string, unknown>;
  };
}

export interface ResourceInventoryItem {
  UID: string;
  resourceId: string;
  resourceType: 'instance' | 'image';
  tenancyId: string;
  compartmentId: string;
  region: string;
  availabilityDomain: string;
  displayName: string;
  state: string;
  platform: 'LINUX' | 'WINDOWS';
  shape: string;
  imageId: string;
  timeCreated: string;
  freeformTags: Record<string, string>;
  definedTags: Record<string, Record<string, string>>;
  volumes: VolumeInfo[];
  scanPriority: number;
  scanSamplingGroup?: string;
  lastDiscoveredAt: string;
  ExpiresAt: number;
}

export interface VolumeInfo {
  volumeId: string;
  volumeType: 'boot' | 'block';
  attachmentId: string;
  sizeInGBs: number;
  availabilityDomain: string;
  isEncrypted: boolean;
  kmsKeyId?: string;
  freeformTags: Record<string, string>;
}

export interface ScanStatusRecord {
  ResourceId: string;
  ScanType: string;
  region: string;
  platform: 'LINUX' | 'WINDOWS';
  status: 'PENDING' | 'BACKING_UP' | 'COPYING' | 'SCANNING' | 'COMPLETED' | 'FAILED' | 'CLEANUP';
  backupIds: string[];
  copyBackupIds: string[];
  scannerInstanceId?: string;
  scannerVolumeIds: string[];
  scanStartTime?: string;
  scanEndTime?: string;
  errorMessage?: string;
  ExpiresAt: number;
}

export interface EventLogEntry {
  UID: string;
  instanceId: string;
  eventType: string;
  eventTime: string;
  region: string;
  tenancyId: string;
  status: 'RECEIVED' | 'PROCESSED' | 'IGNORED';
  details: Record<string, unknown>;
  ExpiresAt: number;
}

export interface DiscoveryTask {
  TaskId: string;
  taskType: 'SCHEDULED' | 'EVENT_BASED' | 'ON_DEMAND' | 'IMAGE';
  taskStatus: 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'FAILED';
  region: string;
  tenancyId: string;
  targetCompartmentId?: string;
  createdAt: string;
  updatedAt: string;
  instanceIds?: string[];
  resourceCount?: number;
  ExpireAt: number;
}

export interface AppConfigEntry {
  configId: string;
  idx: number;
  configValue: string;
  configType: 'SCAN_CONFIG' | 'TAGS_CONFIG' | 'AMI_CONFIG' | 'VERSION_CONFIG' | 'REGION_CONFIG';
  updatedAt: string;
}

export interface ScanConfig {
  regions: string;
  concurrency: number;
  pollFrequency: number;
  scanFrequency: number;
  singleRegionConcurrency: number;
  scanIntervalHours: string;
  swcaEnabled: string;
  secretEnabled: string;
  samplingEnabled: string;
  offlineScanEnabled: string;
  samplingGroupScanPercentage: number;
  swcaScanIncludeDirs: string;
  swcaScanExcludeDirs: string;
  swcaScanTimeout: number;
  secretScanIncludeDirs: string;
  secretScanExcludeDirs: string;
  secretScanTimeout: number;
  amiEnabled: string;
  amiOfflineScanEnabled: string;
  scannerPlatforms: string[];
  cftVersion: string;
}

export interface TagsConfig {
  mustHaveTags: string;
  anyInListTags: string;
  noneInTheList: string;
  noneOnVolume: string;
  qualysTags: string;
}

export interface BackupRequest {
  tenancyId: string;
  region: string;
  volumeId: string;
  volumeType: 'boot' | 'block';
  displayName: string;
  kmsKeyId?: string;
}

export interface BackupCopyRequest {
  tenancyId: string;
  sourceRegion: string;
  sourceBackupId: string;
  destinationRegion: string;
  displayName: string;
  kmsKeyId: string;
}

export interface ScannerLaunchParams {
  compartmentId: string;
  availabilityDomain: string;
  shape: string;
  imageId: string;
  subnetId: string;
  nsgIds: string[];
  displayName: string;
  volumeIds: string[];
  scanType: string;
  resourceId: string;
  metadata: Record<string, string>;
  freeformTags: Record<string, string>;
}

export interface QflowRequest {
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  path: string;
  body?: Record<string, unknown>;
  headers?: Record<string, string>;
}

export interface QflowResponse {
  statusCode: number;
  body: unknown;
  headers: Record<string, string>;
}

export interface FunctionContext {
  appId: string;
  fnId: string;
  callId: string;
  deadline: string;
  config: Record<string, string>;
  headers: Record<string, string[]>;
}

export interface QueueMessage {
  id: string;
  content: string;
  receipt: string;
  deliveryCount: number;
  expireAfter: string;
  visibleAfter: string;
}

export interface OciSdkRequest {
  service: string;
  operation: string;
  tenancyId?: string;
  region?: string;
  params: Record<string, unknown>;
}

export interface OciSdkResponse {
  statusCode: number;
  data: unknown;
  opcRequestId: string;
}
