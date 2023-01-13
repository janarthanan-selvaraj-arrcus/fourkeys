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
  provisioner "local-exec" {
    command = <<EOT
        git clone https://${var.dst_github_token}@github.com/${var.dst_github_org}/${var.dst_github_repo}.git
    EOT
  }
  depends_on = [google_cloud_run_service_iam_binding.dashboard_noauth]
}


resource "null_resource" "CreateNewDestinationBranch" {
  provisioner "local-exec" {
    command = <<EOT
        cd ${var.dst_github_repo}
        git branch ${var.dst_branch_name}
        git checkout ${var.dst_branch_name}
        cd ../
    EOT
  }
  depends_on = [null_resource.cloneDestinationRepository]
}


resource "null_resource" "CopyCommitAndPush" {
  provisioner "local-exec" {
    command = <<EOT

      cp dashboard/fourkeys_dashboard.json ${var.dst_github_repo}/${var.dst_path}
      cd ${var.dst_github_repo}
      git add ${var.dst_path}/*
      git commit -m "Added New Dashboard File"
      git push --set-upstream origin ${var.dst_branch_name}
    EOT
  }
  depends_on = [null_resource.CreateNewDestinationBranch]
}

resource "null_resource" "PullRequest" {
  provisioner "local-exec" {
    command = <<EOT
    curl -X POST -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${var.dst_github_token}"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/${var.dst_github_org}/${var.dst_github_repo}/pulls \
  -d '{"title":"Amazing new feature","body":"Please pull these awesome changes in!","head":"${var.dst_branch_name}","base":"main"}'
    EOT
  }
  depends_on = [null_resource.CopyCommitAndPush]
}