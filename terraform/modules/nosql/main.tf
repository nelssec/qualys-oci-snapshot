# NoSQL Module - 5 tables with indexes for snapshot scanning

# Table 1: Resource Inventory
resource "oci_nosql_table" "resource_inventory" {
  compartment_id = var.compartment_id
  name           = "snapshot_resource_inventory"
  ddl_statement  = <<-EOT
    CREATE TABLE IF NOT EXISTS snapshot_resource_inventory (
      UID STRING,
      resourceId STRING,
      resourceType STRING,
      tenancyId STRING,
      compartmentId STRING,
      region STRING,
      availabilityDomain STRING,
      displayName STRING,
      state STRING,
      platform STRING,
      shape STRING,
      imageId STRING,
      timeCreated STRING,
      freeformTags JSON,
      definedTags JSON,
      volumes JSON,
      scanPriority INTEGER,
      scanSamplingGroup STRING,
      lastDiscoveredAt STRING,
      ExpiresAt LONG,
      PRIMARY KEY (UID)
    ) USING TTL 30 DAYS
  EOT

  table_limits {
    max_read_units     = var.table_read_units
    max_write_units    = var.table_write_units
    max_storage_in_gbs = var.table_storage_gbs
  }

  freeform_tags = var.common_tags
}

resource "oci_nosql_index" "inventory_by_region_state" {
  table_name_or_id = oci_nosql_table.resource_inventory.id
  name             = "byRegionAndState"
  compartment_id   = var.compartment_id

  keys {
    column_name = "region"
  }
  keys {
    column_name = "state"
  }
}

resource "oci_nosql_index" "inventory_by_region_priority" {
  table_name_or_id = oci_nosql_table.resource_inventory.id
  name             = "byRegionAndPriority"
  compartment_id   = var.compartment_id

  keys {
    column_name = "region"
  }
  keys {
    column_name = "scanPriority"
  }
}

resource "oci_nosql_index" "inventory_by_scan_sampling" {
  table_name_or_id = oci_nosql_table.resource_inventory.id
  name             = "byScanSampling"
  compartment_id   = var.compartment_id

  keys {
    column_name = "scanSamplingGroup"
  }
  keys {
    column_name = "region"
  }
}

# Table 2: Scan Status
resource "oci_nosql_table" "scan_status" {
  compartment_id = var.compartment_id
  name           = "snapshot_scan_status"
  ddl_statement  = <<-EOT
    CREATE TABLE IF NOT EXISTS snapshot_scan_status (
      ResourceId STRING,
      ScanType STRING,
      region STRING,
      platform STRING,
      status STRING,
      backupIds JSON,
      copyBackupIds JSON,
      scannerInstanceId STRING,
      scannerVolumeIds JSON,
      scanStartTime STRING,
      scanEndTime STRING,
      errorMessage STRING,
      ExpiresAt LONG,
      PRIMARY KEY (ResourceId, ScanType)
    ) USING TTL 30 DAYS
  EOT

  table_limits {
    max_read_units     = var.table_read_units
    max_write_units    = var.table_write_units
    max_storage_in_gbs = var.table_storage_gbs
  }

  freeform_tags = var.common_tags
}

resource "oci_nosql_index" "scan_status_by_region_platform" {
  table_name_or_id = oci_nosql_table.scan_status.id
  name             = "byRegionAndPlatform"
  compartment_id   = var.compartment_id

  keys {
    column_name = "region"
  }
  keys {
    column_name = "platform"
  }
}

# Table 3: Event Logs
resource "oci_nosql_table" "event_logs" {
  compartment_id = var.compartment_id
  name           = "snapshot_event_logs"
  ddl_statement  = <<-EOT
    CREATE TABLE IF NOT EXISTS snapshot_event_logs (
      UID STRING,
      instanceId STRING,
      eventType STRING,
      eventTime STRING,
      region STRING,
      tenancyId STRING,
      status STRING,
      details JSON,
      ExpiresAt LONG,
      PRIMARY KEY (UID)
    ) USING TTL 30 DAYS
  EOT

  table_limits {
    max_read_units     = var.table_read_units
    max_write_units    = var.table_write_units
    max_storage_in_gbs = var.table_storage_gbs
  }

  freeform_tags = var.common_tags
}

resource "oci_nosql_index" "event_logs_by_instance" {
  table_name_or_id = oci_nosql_table.event_logs.id
  name             = "byInstanceId"
  compartment_id   = var.compartment_id

  keys {
    column_name = "instanceId"
  }
}

# Table 4: Discovery Task
resource "oci_nosql_table" "discovery_task" {
  compartment_id = var.compartment_id
  name           = "snapshot_discovery_task"
  ddl_statement  = <<-EOT
    CREATE TABLE IF NOT EXISTS snapshot_discovery_task (
      TaskId STRING,
      taskType STRING,
      taskStatus STRING,
      region STRING,
      tenancyId STRING,
      targetCompartmentId STRING,
      createdAt STRING,
      updatedAt STRING,
      instanceIds JSON,
      resourceCount INTEGER,
      ExpireAt LONG,
      PRIMARY KEY (TaskId)
    ) USING TTL 30 DAYS
  EOT

  table_limits {
    max_read_units     = var.table_read_units
    max_write_units    = var.table_write_units
    max_storage_in_gbs = var.table_storage_gbs
  }

  freeform_tags = var.common_tags
}

resource "oci_nosql_index" "discovery_task_by_status" {
  table_name_or_id = oci_nosql_table.discovery_task.id
  name             = "byTaskStatus"
  compartment_id   = var.compartment_id

  keys {
    column_name = "taskStatus"
  }
}

# Table 5: App Config
resource "oci_nosql_table" "app_config" {
  compartment_id = var.compartment_id
  name           = "snapshot_app_config"
  ddl_statement  = <<-EOT
    CREATE TABLE IF NOT EXISTS snapshot_app_config (
      configId STRING,
      idx INTEGER,
      configValue STRING,
      configType STRING,
      updatedAt STRING,
      PRIMARY KEY (configId, idx)
    )
  EOT

  table_limits {
    max_read_units     = var.table_read_units
    max_write_units    = var.table_write_units
    max_storage_in_gbs = var.table_storage_gbs
  }

  freeform_tags = var.common_tags
}

resource "oci_nosql_index" "app_config_by_value" {
  table_name_or_id = oci_nosql_table.app_config.id
  name             = "byConfigValue"
  compartment_id   = var.compartment_id

  keys {
    column_name = "configType"
  }
}
