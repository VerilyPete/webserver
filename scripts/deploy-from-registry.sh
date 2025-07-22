#!/bin/bash
# Deploy directly from container registry
set -e
cd ~/webserver

# Configuration
REGISTRY="ghcr.io"
USERNAME="verilypete"
IMAGE_NAME="webserver"

echo "DEPLOYING FROM CONTAINER REGISTRY"
echo "================================="

# Load environment variables
source .env

# Use registry image
export USE_REGISTRY=true
./scripts/deploy.sh

echo "✅ Deployed from registry!"
