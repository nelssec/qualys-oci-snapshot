output "gateway_id" {
  description = "OCID of the API Gateway"
  value       = oci_apigateway_gateway.scanner_gw.id
}

output "gateway_hostname" {
  description = "Hostname of the API Gateway"
  value       = oci_apigateway_gateway.scanner_gw.hostname
}

output "events_endpoint" {
  description = "Full URL for the /events endpoint"
  value       = "${oci_apigateway_gateway.scanner_gw.hostname}/v1/events"
}

output "deployment_id" {
  description = "OCID of the API deployment"
  value       = oci_apigateway_deployment.events_deployment.id
}
