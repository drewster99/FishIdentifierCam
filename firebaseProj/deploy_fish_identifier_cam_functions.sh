#!/bin/bash

# deploy.sh
# Usage: ./deploy.sh

PROJECT_ID="fish-identifier-cam"

echo "Deploying Firebase Cloud Functions v2..."
exec firebase deploy --only functions --project="$PROJECT_ID"
