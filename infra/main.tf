provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

data "google_secret_manager_secret_version" "wp_app_db_user" {
  secret  = "wp-admin-user"
  version = "latest"
}

resource "google_sql_database_instance" "wp_app_db" {
  name             = "wp-base"
  region           = var.gcp_region
  database_version = "MYSQL_8_0"
  settings {
    tier = "db-f1-micro"
  }
}

resource "google_sql_database" "wp_app_db" {
  name     = "wp-base"
  instance = google_sql_database_instance.wp_app_db_instance.name
}

resource "google_sql_user" "wp_app_db_user" {
  name     = "admin"
  instance = google_sql_database_instance.wp_app_db_instance.name
  password = data.google_secret_manager_secret_version.wp_app_db_user.secret_data
}

resource "google_cloud_run_v2_service" "wp_app_gcr" {
  name     = "wp-app"
  location = var.gcp_region
  ingress  = "INGRESS_TRAFFIC_ALL"
  template {
    containers {
      name = "wp-site"
      image = "${var.gcp_region}.pkg.dev/${var.gcp_project}/wp-app/wp-site:${var.app_version}"
      env {
        name = "WORDPRESS_DB_HOST"
        value = "${google_sql_database_instance.wp_app_db_instance.ip_address[0].ip_address}:3306"
      }
      env {
        name = "WORDPRESS_DB_USER"
        value = google_sql_user.wp_app_db_user.name
      }
      env {
        name = "WORDPRESS_DB_PASSWORD"
        value = data.google_secret_manager_secret_version.wp_app_db_user.secret_data
      }
      env {
        name = "WORDPRESS_DB_NAME"
        value = google_sql_database.wp_app_db.name
      }
    }
  }
}
