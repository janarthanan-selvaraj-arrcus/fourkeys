resource "google_cloud_run_service" "dashboard" {
  count    = var.enable_dashboard ? 1 : 0
  name     = "fourkeys-grafana-dashboard"
  location = var.region
  project  = var.project_id
  template {
    spec {
      containers {
        ports {
          name           = "http1"
          container_port = 3000
        }
        image = local.dashboard_container_url
        env {
          name  = "PROJECT_NAME"
          value = var.project_id
        }
      }
      service_account_name = google_service_account.fourkeys.email
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
  metadata {
    labels = { "created_by" : "fourkeys" }
  }
  autogenerate_revision_name = true
  depends_on = [
    time_sleep.wait_for_services
  ]
}

resource "google_cloud_run_service_iam_binding" "dashboard_noauth" {
  count    = var.enable_dashboard ? 1 : 0
  location = var.region
  project  = var.project_id
  service  = "fourkeys-grafana-dashboard"

  role       = "roles/run.invoker"
  members    = ["allUsers"]
  depends_on = [google_cloud_run_service.dashboard]
}

resource "null_resource" "cloneDestinationRepository" {
  count    = var.enable_dashboard ? 0 : 1
  provisioner "local-exec" {
    command = <<EOT
        git clone https://${var.gf_github_token}@wwwin-github.cisco.com/${var.gf_github_org}/${var.gf_github_repo}.git
    EOT
  }
  depends_on = [google_cloud_run_service_iam_binding.dashboard_noauth]
}


resource "null_resource" "CreateNewDestinationBranch" {
  count    = var.enable_dashboard ? 0 : 1
  provisioner "local-exec" {
    command = <<EOT
        cd ${var.gf_github_repo}
        git branch ${var.gf_new_branch}
        git checkout ${var.gf_new_branch}
        cd ../
    EOT
  }
  depends_on = [null_resource.cloneDestinationRepository]
}


resource "null_resource" "CopyCommitAndPush" {
  count    = var.enable_dashboard ? 0 : 1
  provisioner "local-exec" {
    command = <<EOT

      cp ${path.module}/files/fourkeys_dashboard.json ${var.gf_github_repo}/dashboards
      cd ${var.gf_github_repo}
      git add dashboards/*
      git commit -m "Added New Dashboard File"
      git push --set-upstream origin ${var.gf_github_repo}
    EOT
  }
  depends_on = [null_resource.CreateNewDestinationBranch]
}

resource "null_resource" "PullRequest" {
  count    = var.enable_dashboard ? 0 : 1
  provisioner "local-exec" {
    command = <<EOT
    curl -X POST -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${var.gf_github_token}"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://wwwin-github.cisco.com/api/v3/repos/${var.gf_github_org}/${var.gf_github_repo}/pulls \
  -d '{"title":"Added New Dashboard","body":"Added New Dashboard!","head":"${var.gf_github_repo}","base":"${var.gf_base_branch}"}'
    EOT
  }
  depends_on = [null_resource.CopyCommitAndPush]
}
