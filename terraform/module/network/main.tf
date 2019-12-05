provider "google" {
  project     = "${var.project_id}"
  credentials = "${file("../fa19-team-013.json")}"
  region      = "${var.region}"
}

data "google_compute_zones" "available" {
}

#vpc
resource "google_compute_network" "default_vpc" {
  name                    = "${var.vpc_name}"
  auto_create_subnetworks = false
}

#subnet1
resource "google_compute_subnetwork" "subnet1" {
  name                     = "${var.network_name[0]}"
  ip_cidr_range            = "${var.network_cidr[0]}"
  network                  = "${google_compute_network.default_vpc.self_link}"
  region                   = "${var.region}"
  private_ip_google_access = true
}

#subnet2
resource "google_compute_subnetwork" "subnet2" {
  name                     = "${var.network_name[1]}"
  ip_cidr_range            = "${var.network_cidr[1]}"
  network                  = "${google_compute_network.default_vpc.self_link}"
  region                   = "${var.region}"
  private_ip_google_access = true
}

#subnet3
resource "google_compute_subnetwork" "subnet3" {
  name                     = "${var.network_name[2]}"
  ip_cidr_range            = "${var.network_cidr[2]}"
  network                  = "${google_compute_network.default_vpc.self_link}"
  region                   = "${var.region}"
  private_ip_google_access = true
}

## app security group
resource "google_compute_firewall" "app_firewall" {
  name    = "app-firewall"
  network = "${var.vpc_name}"

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8080"]
  }

  source_tags = ["web"]
}


## db security group
resource "google_compute_firewall" "db_firewall" {
  name    = "db-firewall"
  network = "${var.vpc_name}"

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }
}