provider "cloudstack" {
    api_url = "http://10.0.0.216:8080/client/api"
    api_key = "MovpnGs3uZ9I11hCKfbpetAttIrVUL4D0jxHYCbp7KPPgQ8a3_VwHNEp6KPCTrpxb7AN5aUpg2T1or_IxgrYpA"
    secret_key = "c45zKdWRUA_Ika-oU4i0MEwmOPq3CqXUMpkgunyS4C7d0Y596fAt3xSc4CWZQmRVxKuKBXdXQWKD-iljx3mApQ"
}
resource "cloudstack_vpc" "default" {
    name = "${var.vpc_name}"
    cidr = "${var.vpc_cidr}"
    vpc_offering = "Default VPC offering"
    zone = "Pictet-1"
}
variable "vpc_cidr" {
description = " Super CIDR"
default = "192.168.128.0/17"
}
variable "vpc_name" {
description = "VPC name"
default = "Dev_env_2"
}
output "vpc_id" {
value ="${cloudstack_vpc.default.id}"
}
#ACL definition
resource "cloudstack_network_acl" "frontend" {
    name = "frontend"
    description = "used for frontend"
    vpc_id = "${cloudstack_vpc.default.id}"
}
resource "cloudstack_network_acl" "backend" {
    name = "frontend"
    description = "used for backend"
    vpc_id = "${cloudstack_vpc.default.id}"
}

output "acl_frontend_id" {
value ="${cloudstack_network_acl.frontend.id}"
}
output "acl_backend_id" {
value ="${cloudstack_network_acl.backend.id}"
}
#ACL rules
resource "cloudstack_network_acl_rule" "frontend" {
  acl_id = "${cloudstack_network_acl.frontend.id}"

  rule {
    action = "allow"
    cidr_list = ["0.0.0.0/0"]
    protocol = "all"
    ports = ["all"]
    traffic_type = "ingress"
  }
  rule {
    action = "allow"
    cidr_list = ["0.0.0.0/0"]
    protocol = "all"
    ports = ["0-65535"]
    traffic_type = "egress"
  }
}
resource "cloudstack_network_acl_rule" "backend" {
  acl_id = "${cloudstack_network_acl.backend.id}"

  rule {
    action = "allow"
    cidr_list = ["0.0.0.0/0"]
    protocol = "all"
    ports = ["1-65535"]
    traffic_type = "ingress"
  }
  rule {
    action = "allow"
    cidr_list = ["0.0.0.0/0"]
    protocol = "all"
    ports = ["1-65535"]
    traffic_type = "egress"
  }

}
output "acl_frontend_rule_id" {
value ="${cloudstack_network_acl_rule.frontend.id}"
}
output "acl_backend_rule_id" {
value ="${cloudstack_network_acl_rule.backend.id}"
}
# Networks
resource "cloudstack_network" "frontend" {
    name = "frontend-1"
    cidr = "192.168.128.0/24"
    network_offering = "DefaultIsolatedNetworkOfferingForVpcNetworks"
    vpc_id = "${cloudstack_vpc.default.id}"
    acl_id = "${cloudstack_network_acl.frontend.id}"
    zone = "Pictet-1"
}
resource "cloudstack_network" "backend" {
    name = "backend-1"
    cidr = "192.168.129.0/24"
    network_offering = "DefaultIsolatedNetworkOfferingForVpcNetworks"
    vpc_id = "${cloudstack_vpc.default.id}"
    acl_id = "${cloudstack_network_acl.backend.id}"
    zone = "Pictet-1"
}

output "network_frontend_id" {
value ="${cloudstack_network.frontend.id}"
}
output "network_backend_id" {
value ="${cloudstack_network.backend.id}"
}
# IP access
resource "cloudstack_ipaddress" "frontend_first_IP" {
  vpc_id = "${cloudstack_vpc.default.id}"
}
resource "cloudstack_ipaddress" "frontend_second_IP" {
  vpc_id = "${cloudstack_vpc.default.id}"
}
resource "cloudstack_ipaddress" "LB_IP" {
  vpc_id = "${cloudstack_vpc.default.id}"
}
resource "cloudstack_ipaddress" "backend_first_IP" {
  vpc_id = "${cloudstack_vpc.default.id}"
}
variable "instance" {
  default = {
    "0" = "1"
    "1" = "2"
  }
}
resource "cloudstack_instance" "frontend" {
  name = "frontend1"
  service_offering= "Small Instance"
  network_id = "${cloudstack_network.frontend.id}"
  template = "CentOS 5.3(64-bit) no GUI (vSphere)"
  expunge = "true"
  zone = "Pictet-1"
}
resource "cloudstack_instance" "backend" {
  name = "backend1"
  service_offering= "Small Instance"
  network_id = "${cloudstack_network.backend.id}"
  template = "CentOS 5.3(64-bit) no GUI (vSphere)"
  expunge = "true"
  zone = "Pictet-1"
}
# Disks data
resource "cloudstack_disk" "backend" {
  name = "data_backend"
  attach = "true"
  disk_offering = "Small"
  virtual_machine_id = "${cloudstack_instance.backend.id}"
  zone = "Pictet-1"
}
resource "cloudstack_port_forward" "frontend_ssh" {
  ip_address_id = "${cloudstack_ipaddress.frontend_first_IP.id}"

  forward {
    protocol = "tcp"
    private_port = 22
    public_port = 22
    virtual_machine_id = "${cloudstack_instance.frontend.id}"
  }
}
resource "cloudstack_port_forward" "frontend_http" {
  ip_address_id = "${cloudstack_ipaddress.frontend_first_IP.id}"

  forward {
    protocol = "tcp"
    private_port = 80
    public_port = 80
    virtual_machine_id = "${cloudstack_instance.frontend.id}"
  }
}

