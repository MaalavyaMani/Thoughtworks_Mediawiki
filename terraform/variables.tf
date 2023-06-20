
variable "cluster_name" {
  default = "terraform-test"
}
variable "vm_size" {
  default = "Standard_D3_v2"
}
variable "dns_service_ip"{
    default=""
}
variable "docker_bridge_cidr"{
    default=""
}
variable "service_cidr"{
    default=""
}
variable "k8_version"{
    default="1.21.9"
}