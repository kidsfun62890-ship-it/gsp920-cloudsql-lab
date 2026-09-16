#!/usr/bin/env bash
set -euo pipefail

# GSP920 - Task 1: Create Cloud SQL for PostgreSQL with CMEK.
PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
[[ -n "${PROJECT_ID}" && "${PROJECT_ID}" != "(unset)" ]] || { echo "ERROR: Set the lab project first with: gcloud config set project YOUR_PROJECT_ID" >&2; exit 1; }

export PROJECT_ID
export KMS_KEYRING_ID="cloud-sql-keyring"
export KMS_KEY_ID="cloud-sql-key"
export CLOUDSQL_INSTANCE="postgres-orders"

SERVICE_IDENTITY="$(gcloud beta services identity create \
  --service=sqladmin.googleapis.com \
  --project="${PROJECT_ID}" \
  --format='value(email)' 2>/dev/null || true)"

ZONE="$(gcloud compute instances list --filter='name=bastion-vm' --format='value(zone)' | head -n1)"
[[ -n "${ZONE}" ]] || { echo "ERROR: bastion-vm was not found. Start the lab and retry." >&2; exit 1; }
REGION="${ZONE%-[a-z]}"
# The expression above removes the final zone letter, e.g. us-central1-a -> us-central1.

if ! gcloud kms keyrings describe "${KMS_KEYRING_ID}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud kms keyrings create "${KMS_KEYRING_ID}" --location="${REGION}" --project="${PROJECT_ID}"
fi

if ! gcloud kms keys describe "${KMS_KEY_ID}" --keyring="${KMS_KEYRING_ID}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud kms keys create "${KMS_KEY_ID}" \
    --location="${REGION}" \
    --keyring="${KMS_KEYRING_ID}" \
    --purpose=encryption \
    --project="${PROJECT_ID}"
fi

PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
gcloud kms keys add-iam-policy-binding "${KMS_KEY_ID}" \
  --location="${REGION}" \
  --keyring="${KMS_KEYRING_ID}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-cloud-sql.iam.gserviceaccount.com" \
  --role=roles/cloudkms.cryptoKeyEncrypterDecrypter \
  --quiet

AUTHORIZED_IP="$(gcloud compute instances describe bastion-vm --zone="${ZONE}" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')"
CLOUD_SHELL_IP="$(curl -fsS ifconfig.me)"
KEY_NAME="$(gcloud kms keys describe "${KMS_KEY_ID}" --keyring="${KMS_KEYRING_ID}" --location="${REGION}" --project="${PROJECT_ID}" --format='value(name)')"

if gcloud sql instances describe "${CLOUDSQL_INSTANCE}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Cloud SQL instance ${CLOUDSQL_INSTANCE} already exists; leaving it unchanged."
else
  gcloud sql instances create "${CLOUDSQL_INSTANCE}" \
    --project="${PROJECT_ID}" \
    --authorized-networks="${AUTHORIZED_IP}/32,${CLOUD_SHELL_IP}/32" \
    --disk-encryption-key="${KEY_NAME}" \
    --database-version=POSTGRES_14 \
    --cpu=1 \
    --memory=3840MB \
    --region="${REGION}" \
    --root-password='supersecret!' \
    --quiet
fi

echo "Task 1 complete: ${CLOUDSQL_INSTANCE} created/configured in ${REGION}."
