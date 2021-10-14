resource "google_project_service" "bq_api" {
  service                    = "bigquery.googleapis.com"
  disable_dependent_services = true
}

resource "google_bigquery_dataset" "four_keys" {
  dataset_id = "four_keys"
  location   = var.bigquery_region
  depends_on = [
    google_project_service.bq_api
  ]
}

resource "google_bigquery_table" "events_raw" {
  dataset_id          = google_bigquery_dataset.four_keys.dataset_id
  table_id            = "events_raw"
  schema              = file("./events_raw_schema.json")
  deletion_protection = false
}

resource "google_bigquery_table" "view_changes" {
  dataset_id = google_bigquery_dataset.four_keys.dataset_id
  table_id   = "changes"
  view {
    query          = file("../queries/changes.sql")
    use_legacy_sql = false
  }
  deletion_protection = false
  depends_on = [
    google_bigquery_table.events_raw
  ]
}

resource "google_bigquery_routine" "func_json2array" {
  dataset_id   = google_bigquery_dataset.four_keys.dataset_id
  routine_id   = "json2array"
  routine_type = "SCALAR_FUNCTION"
  return_type  = "{\"typeKind\": \"ARRAY\", \"arrayElementType\": {\"typeKind\": \"STRING\"}}"
  language     = "JAVASCRIPT"
  arguments {
    name      = "json"
    data_type = "{\"typeKind\" :  \"STRING\"}"
  }
  definition_body = file("../queries/function_json2array.js")
}

resource "google_bigquery_table" "view_deployments" {
  dataset_id = google_bigquery_dataset.four_keys.dataset_id
  table_id   = "deployments"
  view {
    query          = file("../queries/deployments.sql")
    use_legacy_sql = false
  }
  deletion_protection = false
  depends_on = [
    google_bigquery_table.events_raw,
    google_bigquery_routine.func_json2array
  ]
}

resource "google_bigquery_table" "view_dailydeployments" {
  dataset_id = google_bigquery_dataset.four_keys.dataset_id
  table_id   = "dailydeployments"
  view {
    query          = file("../queries/dailydeployments.sql")
    use_legacy_sql = false
  }
  deletion_protection = false
  depends_on = [
    google_bigquery_table.view_deployments
  ]
}

resource "google_bigquery_table" "view_incidents" {
  dataset_id = google_bigquery_dataset.four_keys.dataset_id
  table_id   = "incidents"
  view {
    query          = file("../queries/incidents.sql")
    use_legacy_sql = false
  }
  deletion_protection = false
  depends_on = [
    google_bigquery_table.events_raw,
    google_bigquery_table.view_deployments
  ]
}

resource "google_bigquery_table" "view_deployfrequency" {
  dataset_id = google_bigquery_dataset.four_keys.dataset_id
  table_id   = "deployfrequency"
  view {
    query          = file("../queries/deployfrequency.sql")
    use_legacy_sql = false
  }
  deletion_protection = false
  depends_on = [
    google_bigquery_table.events_raw,
    google_bigquery_table.view_deployments
  ]
}


resource "google_bigquery_table" "view_medianleadtimetochange" {
  dataset_id = google_bigquery_dataset.four_keys.dataset_id
  table_id   = "medianleadtimetochange"
  view {
    query          = file("../queries/medianleadtimetochange.sql")
    use_legacy_sql = false
  }
  deletion_protection = false
  depends_on = [
    google_bigquery_table.events_raw,
    google_bigquery_table.view_deployments,
    google_bigquery_table.view_changes
  ]
}

resource "google_bigquery_table" "view_timetorestore" {
  dataset_id = google_bigquery_dataset.four_keys.dataset_id
  table_id   = "timetorestore"
  view {
    query          = file("../queries/timetorestore.sql")
    use_legacy_sql = false
  }
  deletion_protection = false
  depends_on = [
    google_bigquery_table.view_incidents,
  ]
}

resource "google_bigquery_table" "view_changefailurerate" {
  dataset_id = google_bigquery_dataset.four_keys.dataset_id
  table_id   = "changefailurerate"
  view {
    query          = file("../queries/changefailurerate.sql")
    use_legacy_sql = false
  }
  deletion_protection = false
  depends_on = [
    google_bigquery_table.view_deployments,
    google_bigquery_table.view_incidents
  ]
}

resource "google_bigquery_table" "view_dailychangefailurerate" {
  dataset_id = google_bigquery_dataset.four_keys.dataset_id
  table_id   = "dailychangefailurerate"
  view {
    query          = file("../queries/dailychangefailurerate.sql")
    use_legacy_sql = false
  }
  deletion_protection = false
  depends_on = [
    google_bigquery_table.view_deployments,
    google_bigquery_table.view_incidents,
    google_bigquery_table.view_changes
  ]
}

resource "google_bigquery_table" "view_dailymediantimetorestore" {
  dataset_id = google_bigquery_dataset.four_keys.dataset_id
  table_id   = "dailymediantimetorestore"
  view {
    query          = file("../queries/dailymediantimetorestore.sql")
    use_legacy_sql = false
  }
  deletion_protection = false
  depends_on = [
    google_bigquery_table.view_deployments,
    google_bigquery_table.view_incidents
  ]
}

resource "google_bigquery_table" "view_dailymedianleadtime" {
  dataset_id = google_bigquery_dataset.four_keys.dataset_id
  table_id   = "dailymedianleadtime"
  view {
    query          = file("../queries/dailymedianleadtime.sql")
    use_legacy_sql = false
  }
  deletion_protection = false
  depends_on = [
    google_bigquery_table.view_deployments,
    google_bigquery_table.view_changes
  ]
}

resource "google_project_iam_member" "parser_bq_project_access" {
  role   = "roles/bigquery.user"
  member = "serviceAccount:${google_service_account.fourkeys.email}"
}

resource "google_bigquery_dataset_iam_member" "parser_bq" {
  dataset_id = google_bigquery_dataset.four_keys.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.fourkeys.email}"
}

resource "google_project_iam_member" "parser_run_invoker" {
  member = "serviceAccount:${google_service_account.fourkeys.email}"
  role   = "roles/run.invoker"
}