#!/bin/bash
set -e

echo "🚀 WEBSERVER DEPLOYMENT"
echo "======================"

cd ~/webserver

# Configuration
REGISTRY="ghcr.io"
USERNAME="verilypete"
IMAGE_NAME="webserver"

# Inject secrets from environment variables (if inject-secrets.sh exists)
if [ -f "./scripts/inject-secrets.sh" ]; then
    echo "Injecting secrets..."
    ./scripts/inject-secrets.sh
fi

# Load environment variables
if [ -f ".env" ]; then
    source .env
else
    echo "❌ No .env file found"
    exit 1
fi

# Validate required secrets
echo "Validating environment variables..."
MISSING_VARS=()

if [[ ! "$TAILSCALE_AUTH_KEY" =~ ^tskey- ]]; then
    MISSING_VARS+=("TAILSCALE_AUTH_KEY")
fi

if [ -z "$CLOUDFLARE_TUNNEL_TOKEN" ] || [[ "$CLOUDFLARE_TUNNEL_TOKEN" == __* ]]; then
    MISSING_VARS+=("CLOUDFLARE_TUNNEL_TOKEN")
fi

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "❌ Missing or invalid environment variables:"
    for var in "${MISSING_VARS[@]}"; do
        echo "   - $var"
    done
    exit 1
fi

echo "✅ Environment validation passed"

# Determine deployment method (default to registry)
USE_REGISTRY=${USE_REGISTRY:-true}

if [ "$USE_REGISTRY" = "true" ]; then
    # Deploy from container registry
    WEB_IMAGE="${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${WEBSITE_REPO_BRANCH:-main}-latest"
    
    echo "Pulling latest image from registry: ${WEB_IMAGE}"
    podman pull ${WEB_IMAGE}
    
    # Tag as local latest for consistency
    podman tag ${WEB_IMAGE} localhost/webserver-web:latest
else
    # Build locally
    WEB_IMAGE="localhost/webserver-web:latest"
    echo "Building local image..."
    if [ -f "./scripts/build.sh" ]; then
        ./scripts/build.sh
    else
        echo "❌ No build.sh script found for local build"
        exit 1
    fi
fi

# Deploy the container
echo "Restarting web container with image: localhost/webserver-web:latest"

# Stop and remove existing container
podman stop webserver-web 2>/dev/null || true
podman rm webserver-web 2>/dev/null || true

# Start new web container
podman run -d \
    --name webserver-web \
    --pod webserver-pod \
    --restart unless-stopped \
    localhost/webserver-web:latest

echo "✅ Container deployment complete!"

# Verify deployment
echo "Container status:"
podman ps | grep webserver-web

echo ""
echo "Testing web server..."
sleep 5
curl -I http://localhost:8081 || echo "⚠️  Web server not responding on localhost:8081"

# Cleanup - restore placeholder version if backup exists
if [ -f .env.backup ]; then
    mv .env.backup .env
    echo "✅ Restored placeholder .env file"
fi

echo "🎉 Deployment complete!"
