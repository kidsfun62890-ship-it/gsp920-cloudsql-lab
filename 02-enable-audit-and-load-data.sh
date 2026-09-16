#!/usr/bin/env bash
set -euo pipefail

# GSP920 - Task 2: Configure pgAudit and populate the orders database.
PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
CLOUDSQL_INSTANCE="postgres-orders"

[[ -n "${PROJECT_ID}" && "${PROJECT_ID}" != "(unset)" ]] || { echo "ERROR: Set the lab project first." >&2; exit 1; }
gcloud sql instances describe "${CLOUDSQL_INSTANCE}" --project="${PROJECT_ID}" >/dev/null

gcloud sql instances patch "${CLOUDSQL_INSTANCE}" \
  --database-flags='cloudsql.enable_pgaudit=on,pgaudit.log=all' \
  --project="${PROJECT_ID}" \
  --quiet

echo "Waiting for the pgAudit patch operation to finish..."
gcloud sql operations list --instance="${CLOUDSQL_INSTANCE}" --project="${PROJECT_ID}" --filter='status!=DONE' --format='value(name)' >/dev/null || true

gcloud sql instances restart "${CLOUDSQL_INSTANCE}" --project="${PROJECT_ID}" --quiet

gcloud sql operations wait "$(gcloud sql operations list --instance="${CLOUDSQL_INSTANCE}" --project="${PROJECT_ID}" --sort-by='~startTime' --limit=1 --format='value(name)')" --project="${PROJECT_ID}" || true

# Create the database and pgAudit extension through the built-in postgres account.
gcloud sql databases create orders --instance="${CLOUDSQL_INSTANCE}" --project="${PROJECT_ID}" 2>/dev/null || true
POSTGRESQL_IP="$(gcloud sql instances describe "${CLOUDSQL_INSTANCE}" --project="${PROJECT_ID}" --format='value(ipAddresses[0].ipAddress)')"
export PGPASSWORD='supersecret!'
psql "sslmode=disable user=postgres hostaddr=${POSTGRESQL_IP} dbname=orders" <<'SQL'
CREATE EXTENSION IF NOT EXISTS pgaudit;
ALTER DATABASE orders SET pgaudit.log = 'read,write';
SQL

export SOURCE_BUCKET='gs://spls/gsp920'
gcloud storage cp "${SOURCE_BUCKET}/create_orders_db.sql" .
gcloud storage cp "${SOURCE_BUCKET}/DDL/distribution_centers_data.csv" .
gcloud storage cp "${SOURCE_BUCKET}/DDL/inventory_items_data.csv" .
gcloud storage cp "${SOURCE_BUCKET}/DDL/order_items_data.csv" .
gcloud storage cp "${SOURCE_BUCKET}/DDL/products_data.csv" .
gcloud storage cp "${SOURCE_BUCKET}/DDL/users_data.csv" .

psql "sslmode=disable user=postgres hostaddr=${POSTGRESQL_IP}" -c '\i create_orders_db.sql'
psql "sslmode=disable user=postgres hostaddr=${POSTGRESQL_IP} dbname=orders" <<'SQL'
CREATE ROLE auditor WITH NOLOGIN;
ALTER DATABASE orders SET pgaudit.role = 'auditor';
GRANT SELECT ON order_items TO auditor;
SQL

unset PGPASSWORD
echo "Task 2 complete: pgAudit configured and orders database populated."
echo "Note: Enable Cloud SQL Admin Read, Data Read, and Data Write under IAM & Admin > Audit Logs if the lab scorer requires the console audit-log setting."

# The lab's three sample SELECT statements are intentionally not run automatically;
# they are only needed to generate audit entries for the observation portion.
# Run them manually if desired, then inspect Logs Explorer with the lab query.
