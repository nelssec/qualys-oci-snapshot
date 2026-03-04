output "scan_data_bucket_name" {
  description = "Name of the scan data bucket"
  value       = oci_objectstorage_bucket.scan_data.name
}

output "artifacts_bucket_name" {
  description = "Name of the artifacts bucket"
  value       = oci_objectstorage_bucket.artifacts.name
}

output "scan_data_bucket_id" {
  value = oci_objectstorage_bucket.scan_data.bucket_id
}

output "artifacts_bucket_id" {
  value = oci_objectstorage_bucket.artifacts.bucket_id
}
