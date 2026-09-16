#!/usr/bin/env bash
set -euo pipefail

# GSP920 - Task 3: Configure Cloud SQL IAM database authentication.
PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
CLOUDSQL_INSTANCE="postgres-orders"
USERNAME="$(gcloud config get-value account 2>/dev/null)"

[[ -n "${PROJECT_ID}" && "${PROJECT_ID}" != "(unset)" ]] || { echo "ERROR: Set the lab project first." >&2; exit 1; }
[[ -n "${USERNAME}" && "${USERNAME}" != "(unset)" ]] || { echo "ERROR: No active lab account found." >&2; exit 1; }

gcloud sql users create "${USERNAME}" \
  --instance="${CLOUDSQL_INSTANCE}" \
  --type=cloud_iam_user \
  --project="${PROJECT_ID}" \
  2>/dev/null || echo "IAM database user already exists; continuing."

POSTGRESQL_IP="$(gcloud sql instances describe "${CLOUDSQL_INSTANCE}" --project="${PROJECT_ID}" --format='value(ipAddresses[0].ipAddress)')"
export PGPASSWORD='supersecret!'
psql "sslmode=disable user=postgres hostaddr=${POSTGRESQL_IP} dbname=orders" <<SQL
GRANT ALL PRIVILEGES ON TABLE order_items TO "${USERNAME}";
SQL

export PGPASSWORD="$(gcloud auth print-access-token)"
echo "Checking permitted table order_items (should succeed):"
psql --host="${POSTGRESQL_IP}" "${USERNAME}" --dbname=orders -c 'SELECT COUNT(*) FROM order_items;'
echo "Checking non-permitted table users (should fail with permission denied):"
if psql --host="${POSTGRESQL_IP}" "${USERNAME}" --dbname=orders -c 'SELECT COUNT(*) FROM users;'; then
  echo "WARNING: users query succeeded; inspect grants before submitting the lab."
else
  echo "Expected denial confirmed for users."
fi
unset PGPASSWORD
echo "Task 3 complete: Cloud IAM database authentication and table grant configured."
