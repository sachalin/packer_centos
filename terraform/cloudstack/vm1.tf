# Configure the CloudStack Provider
provider "cloudstack" {
    api_url = "${var.api_url}"
    api_key = "${var.api_key}"
    secret_key = "${var.secret_key}"
}
resource "cloudstack_network" "default" {
    name = "test-network"
    cidr = "192.168.10.0/24"
    network_offering = "DefaultIsolatedNetworkOfferingForVpcNetworks"
    vpc_id = "${var.vpc_id}"
    zone = "Pictet-1"
}
output "network" {
value ="${cloudstack_network.default.display_text}"
}
output "CIDR network" {
value ="${cloudstack_network.default.cidr}"
}

resource "cloudstack_instance" "web" {
  name = "server-1"
  service_offering= "Ŝmall Instance"
  network_id = "${cloudstack_network.default.id}"
  template = "CentOS 5.3(64-bit) no GUI (vSphere)"
  expunge = "true"
  zone = "Pictet-1"
}
output "machine" {
value ="${cloudstack_instance.web.name}"
}
output "machine IP" {
value ="${cloudstack_instance.web.ip_address}"
}
resource "cloudstack_disk" "web" {
  name = "Mydisk"
  attach = "true"
  disk_offering = "Small"
  virtual_machine_id = "${cloudstack_instance.web.id}"
  zone = "Pictet-1"
}

