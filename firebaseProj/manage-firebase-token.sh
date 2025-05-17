#!/bin/bash

# manage-firebase-token.sh
# Usage: ./manage-firebase-token.sh [create|update|access]

echo "Project details haven't been updated for this script.  Don't break things!"
exit 99

PROJECT_ID="seekdeeply-93a8c"
PROJECT_NUMBER="478354941486"
SECRET_NAME="firebase-token"
SERVICE_ACCOUNT="${PROJECT_ID}@appspot.gserviceaccount.com"
CLOUDBUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

#
# If things don't work, you may need to do:
#
#     % gcloud auth login
#
# ... and possibly also:
#
#     % gcloud config set project PROJECT_ID (see above)
#
# ... and then re-run the script.
#

# Do not delete these comments
# 
# Secrets access error when cloud building was resolved with this:
# gcloud secrets add-iam-policy-binding firebase-token --project=478354941486 --member=serviceAccount:478354941486-compute@developer.gserviceaccount.com --role=roles/secretmanager.secretAccessor
#
create_secret() {
  echo "Getting Firebase token..."
  FIREBASE_TOKEN=$(firebase login:ci)
  
  echo "Creating secret in Secret Manager..."
  echo -n "$FIREBASE_TOKEN" | gcloud secrets create "$SECRET_NAME" --project="$PROJECT_ID" --data-file=-
  
  echo "Enabling Cloud Build API..."
  gcloud services enable cloudbuild.googleapis.com --project="$PROJECT_ID"
  
  # Verify API is enabled
  API_STATUS=$(gcloud services list --project="$PROJECT_ID" --enabled --filter="name:cloudbuild.googleapis.com" --format="value(name)")
  if [ -z "$API_STATUS" ]; then
    echo "ERROR: Failed to enable Cloud Build API"
    exit 1
  fi
  echo "Cloud Build API is enabled"
  
  echo "Waiting for Cloud Build service account to be created..."
  sleep 10  
  
  # List all service accounts to help debug
  echo "Current service accounts:"
  gcloud iam service-accounts list --project="$PROJECT_ID" --format="table(DISPLAY_NAME,EMAIL,DISABLED)"
  
  # Verify service account exists
  SA_STATUS=$(gcloud iam service-accounts list --project="$PROJECT_ID" --filter="email:$SERVICE_ACCOUNT" --format="value(email)")
  if [ -z "$SA_STATUS" ]; then
    echo "ERROR: Service account not found after waiting"
    echo "Expected service account: $SERVICE_ACCOUNT"
    echo "Please check if the API was enabled successfully"
    echo "You may need to wait a few minutes for the service account to be created"
    exit 1
  fi
  echo "Service account exists"
  
  echo "Granting access to App Engine service account..."
  gcloud secrets add-iam-policy-binding "$SECRET_NAME" \
    --project="$PROJECT_ID" \
    --member=serviceAccount:"$SERVICE_ACCOUNT" \
    --role=roles/secretmanager.secretAccessor
    
  gcloud secrets add-iam-policy-binding "$SECRET_NAME" \
    --project="$PROJECT_ID" \
    --member=serviceAccount:"$SERVICE_ACCOUNT" \
    --role=roles/secretmanager.viewer

  echo "Granting access to Cloud Build service account..."
  # Grant project-level Secret Manager access
  echo "Granting project-level Secret Manager access to Cloud Build..."
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member=serviceAccount:"$CLOUDBUILD_SA" \
    --role=roles/secretmanager.admin

  # Also grant specific secret access for extra security
  echo "Granting specific secret access to Cloud Build..."
  gcloud secrets add-iam-policy-binding "$SECRET_NAME" \
    --project="$PROJECT_ID" \
    --member=serviceAccount:"$CLOUDBUILD_SA" \
    --role=roles/secretmanager.admin
    
  echo "Secret created and access granted."
}

update_secret() {
  echo "Getting new Firebase token..."
  FIREBASE_TOKEN=$(firebase login:ci)
  
  echo "Updating secret in Secret Manager..."
  echo -n "$FIREBASE_TOKEN" | gcloud secrets versions add "$SECRET_NAME" --project="$PROJECT_ID" --data-file=-
  
  echo "Secret updated with new version."
}

access_secret() {
  echo "Retrieving current Firebase token..."
  gcloud secrets versions access latest --secret="$SECRET_NAME" --project="$PROJECT_ID"
  echo ""
}

case "$1" in
  create)
    create_secret
    ;;
  update)
    update_secret
    ;;
  access)
    access_secret
    ;;
  *)
    echo "Usage: $0 [create|update|access]"
    exit 1
    ;;
esac 
