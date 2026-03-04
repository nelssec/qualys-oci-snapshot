// Table and resource names
export const NOSQL_TABLES = {
  RESOURCE_INVENTORY: 'snapshot_resource_inventory',
  SCAN_STATUS: 'snapshot_scan_status',
  EVENT_LOGS: 'snapshot_event_logs',
  DISCOVERY_TASK: 'snapshot_discovery_task',
  APP_CONFIG: 'snapshot_app_config',
} as const;

export const QUEUES = {
  RESOURCE_EVENTS: 'snapshot-resource-events',
  DISCOVERY_TASKS: 'snapshot-discovery-tasks',
  BACKUP_REQUESTS: 'snapshot-backup-requests',
  SCAN_REQUESTS: 'snapshot-scan-requests',
  POST_PROCESS: 'snapshot-post-process',
  FAILED_ERRORS: 'snapshot-failed-errors',
} as const;

export const QUEUE_DLQS = {
  RESOURCE_EVENTS_DLQ: 'snapshot-resource-events-dlq',
  DISCOVERY_TASKS_DLQ: 'snapshot-discovery-tasks-dlq',
  BACKUP_REQUESTS_DLQ: 'snapshot-backup-requests-dlq',
  SCAN_REQUESTS_DLQ: 'snapshot-scan-requests-dlq',
  POST_PROCESS_DLQ: 'snapshot-post-process-dlq',
  FAILED_ERRORS_DLQ: 'snapshot-failed-errors-dlq',
} as const;

export const TAGS = {
  APP_TAG_KEY: 'App',
  APP_TAG_VALUE: 'snapshot-scanner',
  DO_NOT_TOUCH_KEY: 'QualysDoNotTouch',
  DO_NOT_TOUCH_VALUE: 'true',
} as const;

export const OBJECT_STORAGE = {
  SCAN_DATA_BUCKET_PREFIX: 'snapshot-scan-data',
  ARTIFACTS_BUCKET: 'snapshot-artifacts',
  RESULTS_PREFIX: 'scan-results/',
  SCANNER_PREFIX: 'scanner-binaries/',
} as const;

export const VAULT = {
  SECRET_NAME_QTOKEN: 'snapshot-qflow-token',
  KEY_NAME: 'snapshot-master-key',
} as const;

export const SCAN_TYPES = {
  VULN: 'VULN',
  SWCA: 'SWCA',
  SECRET: 'SECRET',
} as const;

export const PLATFORMS = {
  LINUX: 'LINUX',
  WINDOWS: 'WINDOWS',
} as const;

export const MAX_CONCURRENT_BACKUPS = 10;
export const FUNCTION_TIMEOUT_MS = 300_000; // 5 minutes
export const DEFAULT_TTL_DAYS = 30;
export const DEFAULT_SCAN_INTERVAL_HOURS = 24;
export const SCANNER_PORT = 8000;

export const OCI_REGIONS = [
  'us-ashburn-1', 'us-phoenix-1', 'us-sanjose-1', 'us-chicago-1',
  'ca-toronto-1', 'ca-montreal-1',
  'eu-frankfurt-1', 'eu-zurich-1', 'eu-amsterdam-1', 'eu-marseille-1',
  'eu-stockholm-1', 'eu-milan-1', 'eu-paris-1', 'eu-madrid-1',
  'uk-london-1', 'uk-cardiff-1',
  'ap-tokyo-1', 'ap-osaka-1', 'ap-sydney-1', 'ap-melbourne-1',
  'ap-mumbai-1', 'ap-hyderabad-1', 'ap-seoul-1', 'ap-chuncheon-1',
  'ap-singapore-1',
  'sa-saopaulo-1', 'sa-vinhedo-1',
  'me-jeddah-1', 'me-dubai-1',
  'af-johannesburg-1',
  'il-jerusalem-1',
] as const;
