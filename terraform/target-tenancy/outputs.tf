output "cross_tenancy_policy_id" {
  description = "OCID of the cross-tenancy admit policy"
  value       = oci_identity_policy.cross_tenancy_admit.id
}

output "event_forwarder_function_id" {
  description = "OCID of the event-forwarder function"
  value       = var.event_based_scan ? oci_functions_function.event_forwarder[0].id : null
}

output "instance_events_rule_id" {
  description = "OCID of the instance events rule"
  value       = var.event_based_scan ? oci_events_rule.instance_launch[0].id : null
}

output "image_events_rule_id" {
  description = "OCID of the image events rule"
  value       = var.event_based_scan ? oci_events_rule.image_available[0].id : null
}
