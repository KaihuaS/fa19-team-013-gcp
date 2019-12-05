provider "google" {
  project     = "${var.project_id}"
  credentials = "${file("../fa19-team-013.json")}"
  region      = "${var.region}"
}

provider "google-beta" {
  project     = "${var.project_id}"
  credentials = "${file("../fa19-team-013.json")}"
  region      = "${var.region}"
}

# get available zones
data "google_compute_zones" "available" {
}

# auto scaler (aws auto scaling group)
resource "google_compute_autoscaler" "auto_scaler" {
  name   = "my-autoscaler"
  zone   = "${data.google_compute_zones.available.names[0]}"
  target = "${google_compute_instance_group_manager.group_manager.self_link}"

  autoscaling_policy {
    max_replicas    = 10
    min_replicas    = 3
    cooldown_period = 60

    cpu_utilization {
      target = 0.05
    }
  }
}

# instance template (aws launch config)
resource "google_compute_instance_template" "instance_template" {
  name           = "my-instance-template"
  machine_type   = "n1-standard-1"
  can_ip_forward = false

  disk {
    source_image = "${data.google_compute_image.centos_7.self_link}"
  }

  network_interface {
    network = "default"
  }

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }

  metadata_startup_script = <<EOF
  #!/bin/bash
  ## install suitable environment
  sudo yum install -y java-1.8.0-openjdk
  sudo yum install -y maven
  ## get ip address of current instance using google cloud sdk
  ## add current ip address to the rds instance authorized network
  
  ## install logging-agent
  curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
  sudo bash install-logging-agent.sh
EOF

  metadata = {
    shutdown-script = <<EOF
      #!/bin/bash
      ## get ip address of current instance using google cloud sdk
      ## remove current ip address from authorized network of the rds instance
      EOF
  }
}

resource "google_compute_target_pool" "target_pool" {
  name = "target-pool"

  health_checks = [
    "${google_compute_http_health_check.default.name}"
  ]
}

resource "google_compute_http_health_check" "default" {
  name               = "default"
  request_path       = "/recipes"
  check_interval_sec = 5
  timeout_sec        = 5
}

# 
resource "google_compute_instance_group_manager" "group_manager" {
  name = "my-gm"
  zone = "${data.google_compute_zones.available.names[0]}"

  version {
    instance_template = "${google_compute_instance_template.instance_template.self_link}"
    name              = "primary"
  }

  target_pools       = ["${google_compute_target_pool.target_pool.self_link}"]
  base_instance_name = "csye6225-webapp"
}

data "google_compute_image" "centos_7" {
  family  = "centos-7"
  project = "centos-cloud"
}

# notification service
resource "google_pubsub_topic" "pubsub_topic" {
  name = "email-notification"
}

resource "google_storage_bucket" "code_bucket" {
  name          = "code-bucket${uuid()}"
  force_destroy = true
}

# upload function code
data "archive_file" "index_zip" {
  type        = "zip"
  source_dir  = "${path.module}/function_code"
  output_path = "/tmp/index.zip"
}

resource "google_storage_bucket_object" "archive" {
  name   = "index.zip"
  bucket = "${google_storage_bucket.code_bucket.name}"
  source = "${data.archive_file.index_zip.output_path}"
}

# cloud function (aws lambda function FaaS)
resource "google_cloudfunctions_function" "function" {
  name        = "function"
  description = "Send email function"
  runtime     = "nodejs8"

  available_memory_mb   = 256
  source_archive_bucket = "${google_storage_bucket.code_bucket.name}"
  source_archive_object = "${google_storage_bucket_object.archive.name}"
  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = "${google_pubsub_topic.pubsub_topic.name}"
  }

  entry_point = "sendEmail"
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = "${google_cloudfunctions_function.function.project}"
  region         = "${google_cloudfunctions_function.function.region}"
  cloud_function = "${google_cloudfunctions_function.function.name}"

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

resource "google_compute_global_forwarding_rule" "https" {
  name       = "https-rule"
  target     = "${google_compute_target_https_proxy.default.self_link}"
  ip_address = "${google_compute_global_address.default.address}"
  port_range = "443"
}

resource "google_compute_global_address" "default" {
  name       = "global-address"
  ip_version = "IPV4"
}

# HTTPS proxy when ssl is true
resource "google_compute_target_https_proxy" "default" {
  name             = "csye6225-https-proxy"
  url_map          = "${google_compute_url_map.default.self_link}"
  ssl_certificates = ["${google_compute_managed_ssl_certificate.default.self_link}"]
}

# google managed ssl certificate
resource "google_compute_managed_ssl_certificate" "default" {
  provider = google-beta
  name     = "ssl-cert"

  managed {
    domains = ["gcp.yixie.me."]
  }
}

data "google_dns_managed_zone" "zone" {
  provider = google-beta
  name     = "gcp"
}

# dns record set
resource "google_dns_record_set" "set" {
  name         = "gcp.yixie.me."
  type         = "A"
  ttl          = 3600
  managed_zone = data.google_dns_managed_zone.zone.name
  rrdatas      = [google_compute_global_forwarding_rule.https.ip_address]
}

resource "google_compute_url_map" "default" {
  name            = "url-map"
  default_service = google_compute_backend_service.default.self_link

  host_rule {
    hosts        = ["gcp.yixie.me"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.default.self_link

    path_rule {
      paths   = ["/*"]
      service = google_compute_backend_service.default.self_link
    }
  }
}

# back end service
resource "google_compute_backend_service" "default" {
  name          = "backend-service"
  health_checks = ["${google_compute_http_health_check.default.self_link}"]

  # manually config (didn't support instance group manager only support instance group)
  #   backend {
  #       group = "${google_compute_instance_group_manager.group_manager.self_link}"
  #   }
}

# HTTPS health check with backend_protocol is "HTTPS"
resource "google_compute_https_health_check" "default" {
  name               = "health-check"
  request_path       = "/recipes"
  check_interval_sec = 5
  timeout_sec        = 5
  port               = 8080
}