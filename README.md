# OCI Snapshot Scanning Platform

A fully OCI-native snapshot scanning platform that enables centralized vulnerability, software composition, and secret scanning across multiple OCI tenancies. Built from the ground up to leverage OCI's native services and cross-tenancy federation model.

## Why This Exists

Cloud security scanning at scale requires inspecting the actual contents of compute volumes, not just API metadata. This platform creates temporary backups of volumes across your OCI estate, mounts them to ephemeral scanner instances, runs deep scans (vulnerability, SWCA, secrets), and reports results back to a central orchestrator. All without installing agents on production workloads.

The challenge in OCI is that tenancy boundaries are hard boundaries. Cross-tenancy access requires endorse/admit policy pairs at root compartment level, and there is no direct snapshot sharing between tenancies. This platform handles that complexity so scanning teams can operate across organizational tenancies seamlessly.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SCANNING TENANCY                             │
│                                                                     │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────────┐    │
│  │   API    │   │   OCI    │   │  NoSQL   │   │   Object     │    │
│  │ Gateway  │──▶│Functions │──▶│ Database │   │   Storage    │    │
│  └────┬─────┘   └────┬─────┘   └────┬─────┘   └──────────────┘    │
│       │              │              │                               │
│       │         ┌────▼─────┐   ┌────▼─────┐                       │
│       │         │  Queue   │   │Connector │                        │
│       │         │ Service  │   │   Hub    │──▶ qflow               │
│       │         └──────────┘   └──────────┘                        │
│       │                                                             │
│       │         ┌──────────┐   ┌──────────┐                       │
│       │         │  Vault   │   │   VCN    │                        │
│       │         │  (KMS)   │   │(Private) │                        │
│       │         └──────────┘   └──────────┘                        │
└───────┼─────────────────────────────────────────────────────────────┘
        │
        │ Cross-Tenancy (Endorse/Admit Policies)
        │
┌───────▼─────────────────────────────────────────────────────────────┐
│                     TARGET TENANCY (1..N)                            │
│                                                                     │
│  ┌──────────┐   ┌──────────────┐   ┌──────────────────────────┐   │
│  │  Event   │──▶│   Event      │──▶│ Scanning Tenancy API GW  │   │
│  │  Rules   │   │  Forwarder   │   │ (via HTTPS)              │   │
│  └──────────┘   └──────────────┘   └──────────────────────────┘   │
│                                                                     │
│  Cross-tenancy admit policy at root compartment                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Core Components

### Scanning Tenancy (Central Hub)

| Component | Purpose |
|-----------|---------|
| **OCI Functions (23)** | Serverless workflow steps - discovery, backup, scanning, cleanup |
| **NoSQL Database (5 tables)** | State tracking - inventory, scan status, events, tasks, config |
| **Queue Service (6 queues + 6 DLQs)** | Decoupled workflow orchestration with backpressure handling |
| **Object Storage** | Scan results and scanner artifacts |
| **Vault (HSM)** | Encrypted secret storage for API tokens |
| **VCN** | Private networking for functions and scanner instances |
| **API Gateway** | External entry point for events and qflow integration |
| **Connector Hub** | Streams NoSQL table changes to qflow in real time |
| **Monitoring** | Alarms, dashboards, structured logging |

### Target Tenancy (Lightweight)

| Component | Purpose |
|-----------|---------|
| **Cross-tenancy policy** | Root compartment admit policy allowing scanning tenancy access |
| **Event Forwarder** | (Optional) Forwards instance launch/image creation events to scanning tenancy |
| **Event Rules** | (Optional) Triggers event forwarder on new compute resources |

## Scanning Workflow

The platform operates in six phases, all driven by queue-based orchestration:

### 1. Discovery
Enumerates compute instances and their volumes across target tenancies. Supports three trigger modes:
- **Scheduled**: Periodic full discovery via `discovery-scheduler`
- **Event-based**: Near real-time via target tenancy event forwarding
- **On-demand**: Direct API call for specific instances

The `discovery-worker` performs cross-tenancy API calls, applies tag-based filters, and populates the `resource_inventory` table.

### 2. Scan Planning
`generate-scan-chunks` creates work items as a cross-product of scan types (VULN, SWCA, SECRET), platforms (Linux, Windows), and resource chunks. `fetch-inventory-chunks` queries the inventory with pagination and sampling support. `create-scan-status` initializes tracking records.

### 3. Backup & Copy
Creates volume backups in target tenancies (max 10 concurrent per tenancy/region, an OCI platform limit). For cross-region scanning, copies backups to the scanning tenancy's region.

### 4. Scanning
`generate-scan-params` builds compute instance launch specs with the backed-up volumes attached read-only. Scanner instances boot with cloud-init scripts that mount volumes, run scans, and upload results to Object Storage. `proxy-instance` enables qflow-to-scanner communication within the private VCN.

### 5. Result Processing
`process-scan-files` parses JSON results from Object Storage. `post-process-scan` sends aggregated findings to qflow and marks resources for cleanup.

### 6. Cleanup
`stack-cleanup` terminates scanner instances, deletes volume copies and backups. `scheduled-fn-check` detects and recovers stalled operations.

## The qflow Orchestrator

qflow is the external orchestration engine that drives the scanning workflow end-to-end. It is the control plane that coordinates when and what to scan, monitors progress, and consumes results.

### What qflow does
- **Schedules discovery** by calling the scanning tenancy's API Gateway
- **Monitors progress** via Connector Hub streams (real-time NoSQL change events)
- **Manages workflow state** - deciding when to proceed from discovery to backup to scanning
- **Consumes scan results** and integrates them into the broader security platform
- **Handles retries and error recovery** for the overall workflow

### Current Status

qflow is designed as a separate component that needs to be built. The scanning platform (this repo) provides all the infrastructure and serverless functions, but the orchestration logic that ties the phases together lives in qflow.

### How it works today (workaround)

Until qflow is fully built out, the functions can be invoked directly through the API Gateway. Each function is independently callable, and the queue-based architecture means you can drive the workflow manually or with simple scripts:

1. Call `discovery-scheduler` to kick off discovery
2. Poll the `discovery_task` table or wait for Connector Hub events
3. Call `generate-scan-chunks` → `fetch-inventory-chunks` → `create-scan-status` to set up scans
4. The queue-driven backup/scan/cleanup phases proceed semi-autonomously once resources are enqueued

The Connector Hub streams provide real-time state changes, so any simple consumer (even a script polling the `qflow-api` function) can act as a lightweight orchestrator. The functions are designed to be idempotent and resumable, making manual orchestration safe.

### Building qflow

A full qflow implementation would be a stateful workflow engine (potentially another OCI Function application, a container on OKE, or an external service) that:

1. Maintains a workflow state machine per scan job
2. Listens to Connector Hub streams for state transitions
3. Calls the appropriate next function when a phase completes
4. Implements retry logic with exponential backoff
5. Provides a dashboard/API for scan job status
6. Handles scheduling (cron-like) for periodic discovery

The API contract is already defined - qflow communicates via the API Gateway endpoints and receives events via the `qflow-api` function.

## Project Structure

```
oci-snapshot/
├── terraform/
│   ├── modules/
│   │   ├── iam/              # Dynamic groups, policies, cross-tenancy
│   │   ├── vault/            # KMS vault, master key, secrets
│   │   ├── vcn/              # VCN, subnets, NAT, NSGs
│   │   ├── nosql/            # 5 tables with indexes and TTL
│   │   ├── queues/           # 6 queues + 6 dead-letter queues
│   │   ├── object-storage/   # Scan data and artifact buckets
│   │   ├── functions/        # 23 function definitions
│   │   ├── api-gateway/      # Public API with custom auth
│   │   ├── events/           # Connector Hub pipes
│   │   └── monitoring/       # Alarms and dashboards
│   ├── scanning-tenancy/     # Root module - composes all modules
│   └── target-tenancy/       # Cross-tenancy policies + event forwarding
├── functions/
│   ├── shared/
│   │   └── lib/              # 11 shared TypeScript libraries
│   │       ├── constants.ts
│   │       ├── types.ts
│   │       ├── api-client.ts
│   │       ├── nosql-client.ts
│   │       ├── queue-client.ts
│   │       ├── oci-client.ts
│   │       ├── cross-tenancy.ts
│   │       ├── data-formatter.ts
│   │       ├── tag-filter.ts
│   │       ├── vault-client.ts
│   │       └── logger.ts
│   ├── discovery-scheduler/
│   ├── discovery-worker/
│   ├── event-task-scheduler/
│   ├── event-forwarder/      # Deployed to target tenancy
│   ├── on-demand-scan/
│   ├── generate-scan-chunks/
│   ├── fetch-inventory-chunks/
│   ├── create-scan-status/
│   ├── generate-scan-params/
│   ├── proxy-instance/
│   ├── process-scan-files/
│   ├── post-process-scan/
│   ├── stack-cleanup/
│   ├── image-cleanup/
│   ├── image-discovery-scheduler/
│   ├── scheduled-fn-check/
│   ├── qflow-api/
│   ├── app-config-store/
│   ├── oci-sdk-wrapper/
│   ├── nosql-wrapper/
│   ├── data-formatter/
│   ├── download-to-storage/
│   ├── update-function-code/
│   └── create-bucket/
├── scripts/
│   ├── deploy-scanning-tenancy.sh
│   ├── deploy-target-tenancy.sh
│   ├── validate-cross-tenancy.sh
│   ├── test-event-flow.sh
│   └── integration-test.sh
└── tests/
    └── unit tests for tag-filter, data-formatter, constants
```

## Deployment

### Prerequisites
- OCI CLI configured with appropriate permissions
- Terraform >= 1.0
- Node.js >= 18
- Docker (for building function container images)
- `gh` CLI (optional, for GitHub operations)
- OCIR (OCI Container Registry) access for pushing function images

### Scanning Tenancy

```bash
# Set required environment variables
export TF_VAR_tenancy_id="ocid1.tenancy.oc1..your-scanning-tenancy"
export TF_VAR_compartment_id="ocid1.compartment.oc1..your-compartment"
export TF_VAR_region="us-ashburn-1"
export TF_VAR_qflow_token="your-qflow-api-token"
export TF_VAR_qflow_endpoint="https://your-qflow-endpoint"
export TF_VAR_ocir_registry="iad.ocir.io/your-namespace"
export TF_VAR_object_storage_namespace="your-namespace"
export TF_VAR_target_tenancy_ids='["ocid1.tenancy.oc1..target1","ocid1.tenancy.oc1..target2"]'

# Deploy
./scripts/deploy-scanning-tenancy.sh apply
```

The deployment script handles TypeScript compilation, Docker image builds, OCIR pushes, and Terraform apply.

### Target Tenancy

```bash
export TF_VAR_tenancy_id="ocid1.tenancy.oc1..your-target-tenancy"
export TF_VAR_scanning_tenancy_id="ocid1.tenancy.oc1..your-scanning-tenancy"
export TF_VAR_scanning_dynamic_group_id="ocid1.dynamicgroup.oc1..scanner-dg"
export TF_VAR_scanning_api_gateway_endpoint="https://your-api-gw.apigateway.us-ashburn-1.oci.customer-oci.com"

# Deploy (cross-tenancy policy + optional event forwarding)
./scripts/deploy-target-tenancy.sh apply
```

### Validation

```bash
# Verify cross-tenancy access
./scripts/validate-cross-tenancy.sh

# Test event forwarding pipeline
./scripts/test-event-flow.sh

# Run integration test
./scripts/integration-test.sh
```

## Security Model

- **No credentials stored in code** - all secrets managed via OCI Vault with HSM encryption
- **Resource Principal authentication** - functions and instances authenticate via IAM dynamic groups, no API keys
- **Cross-tenancy federation** - endorse/admit policy pairs at root compartment level, no shared credentials
- **Private networking** - functions and scanner instances run in private subnets with no public IPs
- **Network security groups** - scanner instances restricted to internal scanning traffic only
- **API authentication** - API Gateway uses custom auth function validating bearer tokens
- **Encrypted at rest** - NoSQL, Object Storage, and Vault all use OCI-managed or customer-managed encryption keys
- **TTL on data** - scan data auto-expires after 30 days

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Queue-driven workflow | Decouples phases, handles backpressure, enables retry via DLQs |
| 10 concurrent backup limit | OCI platform constraint - enforced via queue channel limits |
| 5-minute function timeout | OCI Functions limit - polling pattern splits long operations |
| Connector Hub for state sync | Real-time NoSQL change streaming without custom webhooks |
| Serverless compute | No infrastructure to manage, scales to zero, resource principal auth |
| Sampling groups | Statistical scanning for large deployments (scan a percentage) |
| Idempotent functions | Safe retries, manual orchestration, and crash recovery |

## OCI Services Used

- OCI Functions (container-based, Node.js/TypeScript)
- OCI NoSQL Database
- OCI Queue Service
- OCI Object Storage
- OCI Vault (KMS)
- OCI Virtual Cloud Network
- OCI API Gateway
- OCI Connector Hub
- OCI Events
- OCI Monitoring (Alarms + Dashboards)
- OCI Logging
- OCI Container Registry (OCIR)

## License

See [LICENSE](LICENSE) for details.
