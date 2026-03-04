output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.scanner_vcn.id
}

output "private_subnet_id" {
  description = "OCID of the private scanner subnet"
  value       = oci_core_subnet.scanner_subnet.id
}

output "public_subnet_id" {
  description = "OCID of the public subnet"
  value       = var.create_public_subnet ? oci_core_subnet.public_subnet[0].id : null
}

output "scanner_nsg_id" {
  description = "OCID of the scanner NSG"
  value       = oci_core_network_security_group.scanner_nsg.id
}

output "nat_gateway_id" {
  description = "OCID of the NAT Gateway"
  value       = oci_core_nat_gateway.nat_gw.id
}

output "service_gateway_id" {
  description = "OCID of the Service Gateway"
  value       = oci_core_service_gateway.service_gw.id
}
