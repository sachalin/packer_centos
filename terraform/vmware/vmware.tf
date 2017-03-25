# Configure the VMware vSphere Provider
provider "vsphere" {
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  vsphere_server = "${var.vsphere_server}"
  allow_unverified_ssl = true
}
resource "vsphere_virtual_machine" "myvmware1" {
  name   = "myvmware1"
  vcpu   = 1
  memory = 1024
  domain = "MYDOMAIN"
  datacenter = "TESTING"
  cluster = "118"
network_interface {
      label = "VMNetwork"
  }
disk {
    datastore = "10.0.0.118"
    template = "terraform"
  }
disk {
    datastore = "10.0.0.118"
    name = "MyterraDisk"
    size = "2"
  }
}
