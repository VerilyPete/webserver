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

# Ensure user systemd environment is set up
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    echo "Setting up user systemd environment..."
    sudo systemctl start user@$(id -u).service
    sleep 2
fi

# Ensure user lingering is enabled
if ! loginctl show-user $(whoami) 2>/dev/null | grep -q "Linger=yes"; then
    echo "Enabling user lingering..."
    sudo loginctl enable-linger $(whoami)
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
    if ! podman pull ${WEB_IMAGE}; then
        echo "❌ Failed to pull image from registry"
        exit 1
    fi
    
    # Tag as local latest for consistency
    echo "Tagging image as localhost/webserver-web:latest"
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

# Check if we should use systemd service management
if systemctl --user is-active webserver-pod.service >/dev/null 2>&1; then
    echo "Using systemd service management..."
    # Stop the service to clean up existing containers
    systemctl --user stop webserver-pod.service 2>/dev/null || true
    # Start the service to recreate everything
    systemctl --user start webserver-pod.service
    echo "✅ Service restarted successfully"
else
    echo "Systemd service not active, managing containers directly..."
    
    # Debug: Show current pod status
    echo "Current pod status:"
    podman pod ps || echo "No pods found"
    
    # Ensure the pod exists
    echo "Ensuring webserver-pod exists..."
    podman pod create --name webserver-pod --publish 8081:8081 --replace 2>/dev/null || true
    
    # Debug: Show pod status after creation
    echo "Pod status after creation:"
    podman pod ps
    
    # Stop and remove existing container (use consistent naming with start-web-pod.sh)
    podman stop web 2>/dev/null || true
    podman rm web 2>/dev/null || true
    
    # Start new web container (use consistent naming with start-web-pod.sh)
    echo "Starting web container..."
    podman run -d \
        --name web \
        --pod webserver-pod \
        --restart unless-stopped \
        localhost/webserver-web:latest
    
    echo "✅ Container deployment complete!"
fi

# Verify deployment
echo "Container status:"
podman ps | grep web || echo "No web containers found"

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
