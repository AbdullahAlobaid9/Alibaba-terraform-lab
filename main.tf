
provider "alicloud" {
  access_key = var.access_key
  secret_key = var.secret_key
  region = "me-central-1"
}


resource "alicloud_vpc" "vpc" {
  description = "vpc"
  cidr_block  = "10.0.0.0/8"
  vpc_name    = "terraform-alicloud"
}


data "alicloud_zones" "zone" {
  available_disk_category     = "cloud_efficiency"
  available_resource_creation = "VSwitch"
}

resource "alicloud_vswitch" "public" {
  vpc_id       = alicloud_vpc.vpc.id
  cidr_block   = "10.0.1.0/24"
  zone_id      = data.alicloud_zones.zone.zones.0.id
  vswitch_name = "public"
}

resource "alicloud_security_group" "http_group" {
  name        = "security_group"
  description = "New security group"
  vpc_id = alicloud_vpc.vpc.id
}

resource "alicloud_security_group_rule" "allow_ssh" {
  type              = "ingress"
  ip_protocol       = "tcp"
  policy            = "accept"
  port_range        = "22/22"
  priority          = 1
  security_group_id = alicloud_security_group.http_group.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "allow_nginx" {
  type              = "ingress"
  ip_protocol       = "tcp"
  policy            = "accept"
  port_range        = "80/80"
  priority          = 1
  security_group_id = alicloud_security_group.http_group.id
  cidr_ip           = "0.0.0.0/0"
}


resource "alicloud_ecs_key_pair" "ssh_key" {
  key_pair_name = "ssh_key"
  key_file = "./tera-ssh.pem"
}


resource "alicloud_instance" "http" {
    count = 1  
  availability_zone = data.alicloud_zones.zone.zones.0.id
  security_groups   = [alicloud_security_group.http_group.id]

  # series III
  instance_type              = "ecs.g6.large"
  system_disk_category       = "cloud_essd"
  image_id                   = "ubuntu_24_04_x64_20G_alibase_20240812.vhd"
  instance_name              = "http-${count.index}"
  vswitch_id                 = alicloud_vswitch.public.id
  internet_max_bandwidth_out = 100
  internet_charge_type = "PayByTraffic"
  instance_charge_type = "PostPaid"
  key_name = alicloud_ecs_key_pair.ssh_key.key_pair_name
  user_data = base64encode(file("http-setup.sh"))

}

output "http" {
    value = alicloud_instance.http.*.public_ip
}