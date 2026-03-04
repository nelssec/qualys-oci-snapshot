# VCN Module - Networking for Scanning Tenancy

resource "oci_core_vcn" "scanner_vcn" {
  compartment_id = var.compartment_id
  display_name   = "snapshot-scanner-vcn"
  cidr_blocks    = [var.vcn_cidr]
  dns_label      = "snapscan"

  freeform_tags = var.common_tags
}

# Private subnet for scanner instances
resource "oci_core_subnet" "scanner_subnet" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.scanner_vcn.id
  display_name               = "snapshot-scanner-private-subnet"
  cidr_block                 = var.subnet_cidr
  prohibit_public_ip_on_vnic = true
  dns_label                  = "scanpriv"

  route_table_id    = oci_core_route_table.private_rt.id
  security_list_ids = [oci_core_vcn.scanner_vcn.default_security_list_id]

  freeform_tags = var.common_tags
}

# NAT Gateway for outbound internet access (Functions + scanner instances)
resource "oci_core_nat_gateway" "nat_gw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.scanner_vcn.id
  display_name   = "snapshot-scanner-nat-gw"

  freeform_tags = var.common_tags
}

# Service Gateway for OCI service access (Object Storage) without internet
resource "oci_core_service_gateway" "service_gw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.scanner_vcn.id
  display_name   = "snapshot-scanner-service-gw"

  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }

  freeform_tags = var.common_tags
}

data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

# Route table for private subnet
resource "oci_core_route_table" "private_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.scanner_vcn.id
  display_name   = "snapshot-scanner-private-rt"

  route_rules {
    network_entity_id = oci_core_nat_gateway.nat_gw.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    description       = "Route to NAT Gateway for outbound internet"
  }

  route_rules {
    network_entity_id = oci_core_service_gateway.service_gw.id
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    description       = "Route to Service Gateway for OCI services"
  }

  freeform_tags = var.common_tags
}

# NSG for scanner instances - allows proxy-instance Function to communicate on port 8000
resource "oci_core_network_security_group" "scanner_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.scanner_vcn.id
  display_name   = "snapshot-scanner-nsg"

  freeform_tags = var.common_tags
}

# Allow inbound TCP 8000 from within the VCN (proxy-instance Function)
resource "oci_core_network_security_group_security_rule" "scanner_inbound_8000" {
  network_security_group_id = oci_core_network_security_group.scanner_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  description               = "Allow inbound TCP 8000 from VCN for proxy-instance"

  source      = var.vcn_cidr
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 8000
      max = 8000
    }
  }
}

# Allow all outbound traffic from scanner instances
resource "oci_core_network_security_group_security_rule" "scanner_outbound_all" {
  network_security_group_id = oci_core_network_security_group.scanner_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  description               = "Allow all outbound traffic from scanner instances"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"
}

# Internet Gateway (optional, for API Gateway if needed)
resource "oci_core_internet_gateway" "internet_gw" {
  count = var.create_public_subnet ? 1 : 0

  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.scanner_vcn.id
  display_name   = "snapshot-scanner-igw"
  enabled        = true

  freeform_tags = var.common_tags
}

# Public subnet for API Gateway (optional)
resource "oci_core_subnet" "public_subnet" {
  count = var.create_public_subnet ? 1 : 0

  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.scanner_vcn.id
  display_name   = "snapshot-scanner-public-subnet"
  cidr_block     = var.public_subnet_cidr
  dns_label      = "scanpub"

  route_table_id    = oci_core_route_table.public_rt[0].id
  security_list_ids = [oci_core_vcn.scanner_vcn.default_security_list_id]

  freeform_tags = var.common_tags
}

resource "oci_core_route_table" "public_rt" {
  count = var.create_public_subnet ? 1 : 0

  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.scanner_vcn.id
  display_name   = "snapshot-scanner-public-rt"

  route_rules {
    network_entity_id = oci_core_internet_gateway.internet_gw[0].id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    description       = "Route to Internet Gateway"
  }

  freeform_tags = var.common_tags
}
