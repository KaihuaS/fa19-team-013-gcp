provider "google" {
  project     = "${var.project_id}"
  credentials = "${file("../fa19-team-013.json")}"
  region      = "${var.region}"
}

# rds
resource "google_sql_database_instance" "sql_database" {
  name             = "database${uuid()}"
  database_version = "MYSQL_5_6"

  settings {
    tier = "db-f1-micro"
  }
}

resource "google_sql_user" "user" {
  name     = "dbuser"
  instance = "${google_sql_database_instance.sql_database.name}"
  password = "Passw0rd!"
}

# Cloud Bigtable (disabled because too expensive)
# resource "google_bigtable_instance" "nosql_instance" {
#   name = "nosql-instance"

#   cluster {
#     cluster_id   = "nosql-instance-cluster"
#     zone         = "${data.google_compute_zones.available.names[0]}"
#     num_nodes    = 3
#     storage_type = "HDD"
#   }
# }

# s3 bucket
resource "google_storage_bucket" "image_store" {
  name          = "webapp${uuid()}"
  location      = "US"
  force_destroy = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
}