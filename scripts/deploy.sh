#!/bin/bash
set -e
cd ~/webserver

# Configuration
REGISTRY="ghcr.io"
USERNAME="verilypete"
IMAGE_NAME="webserver"

echo "Deploying webserver from container registry..."

# Load environment variables
source .env

# Determine which image to use
if [ "${USE_REGISTRY:-false}" = "true" ]; then
    WEB_IMAGE="${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${WEBSITE_REPO_BRANCH:-main}-latest"
    
    echo "Pulling latest image from registry: ${WEB_IMAGE}"
    podman pull ${WEB_IMAGE}
    
    # Tag as local latest for consistency
    podman tag ${WEB_IMAGE} localhost/webserver-web:latest
else
    WEB_IMAGE="localhost/webserver-web:latest"
    echo "Building local image..."
    ./scripts/build.sh
fi

# Restart web container to use new image
echo "Restarting web container with image: ${WEB_IMAGE}"
podman stop webserver-web 2>/dev/null || true
podman rm webserver-web 2>/dev/null || true

# Start new web container
podman run -d \
    --name webserver-web \
    --pod webserver-pod \
    --restart unless-stopped \
    localhost/webserver-web:latest

echo "Deployment complete!"
echo "Container status:"
podman ps | grep webserver-web
echo ""
echo "Testing web server..."
sleep 5
curl -I http://localhost:8081 || echo "Web server not responding"
