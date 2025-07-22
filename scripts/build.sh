#!/bin/bash
set -e
cd ~/webserver

echo "Building web container with website content..."

# Preserve exported environment variables
EXPORTED_PUSH_TO_REGISTRY="${PUSH_TO_REGISTRY}"
EXPORTED_GHCR_TOKEN="${GHCR_TOKEN}"
EXPORTED_FORMSPREE_ENDPOINT="${FORMSPREE_ENDPOINT}"

# Load environment variables from .env
if [ -f .env ]; then
    source .env
fi

# Restore exported variables if they were set
if [ -n "${EXPORTED_PUSH_TO_REGISTRY}" ]; then
    PUSH_TO_REGISTRY="${EXPORTED_PUSH_TO_REGISTRY}"
fi

if [ -n "${EXPORTED_GHCR_TOKEN}" ] && [ "${EXPORTED_GHCR_TOKEN}" != "__GHCR_TOKEN__" ]; then
    GHCR_TOKEN="${EXPORTED_GHCR_TOKEN}"
fi

if [ -n "${EXPORTED_FORMSPREE_ENDPOINT}" ] && [ "${EXPORTED_FORMSPREE_ENDPOINT}" != "__FORMSPREE_ENDPOINT__" ]; then
    FORMSPREE_ENDPOINT="${EXPORTED_FORMSPREE_ENDPOINT}"
fi

# Inject secrets into nginx.conf before building
if [ -f web/nginx.conf.template ]; then
    echo "Generating nginx.conf from template..."
    sed "s|__FORMSPREE_ENDPOINT__|${FORMSPREE_ENDPOINT}|g" web/nginx.conf.template > web/nginx.conf
    echo "✅ nginx.conf generated with Formspree endpoint"
fi

# Configuration
REGISTRY="ghcr.io"
USERNAME="verilypete"
IMAGE_NAME="webserver"
TAG="${WEBSITE_REPO_BRANCH:-main}-$(date +%Y%m%d-%H%M%S)"
LATEST_TAG="${WEBSITE_REPO_BRANCH:-main}-latest"

echo "Building image: ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${TAG}"

# Build web container with website content baked in
podman build --platform=linux/arm64 \
    --build-arg REPO_URL=${WEBSITE_REPO_URL:-https://github.com/VerilyPete/peterhollmer.com.git} \
    --build-arg REPO_BRANCH=${WEBSITE_REPO_BRANCH:-main} \
    -t localhost/webserver-web:latest \
    -t ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${TAG} \
    -t ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${LATEST_TAG} \
    ./web

echo "✅ Container built successfully!"

# Cleanup - restore template version
if [ -f web/nginx.conf.template ]; then
    cp web/nginx.conf.template web/nginx.conf
    echo "✅ Restored template nginx.conf"
fi

# Check if we should push to registry
if [ "${PUSH_TO_REGISTRY}" = "true" ]; then
    echo "Pushing to registry..."
    
    # Login to registry
    if [ -n "${GHCR_TOKEN}" ] && [ "${GHCR_TOKEN}" != "__GHCR_TOKEN__" ]; then
        echo "${GHCR_TOKEN}" | podman login ${REGISTRY} -u ${USERNAME} --password-stdin
        
        # Push images
        podman push ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${TAG}
        podman push ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${LATEST_TAG}
        
        echo "✅ Images pushed to registry:"
        echo "   ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${TAG}"
        echo "   ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${LATEST_TAG}"
    else
        echo "❌ GHCR_TOKEN not set or is placeholder, cannot push to registry"
        exit 1
    fi
else
    echo "Local build complete. To push to registry:"
    echo "  export PUSH_TO_REGISTRY=true"
    echo "  export GHCR_TOKEN=your-github-token"
    echo "  export FORMSPREE_ENDPOINT=https://formspree.io/f/your-form-id"
    echo "  ./scripts/build.sh"
fi

echo ""
echo "Images built:"
podman images | grep -E "(webserver|ghcr.io)" || echo "No webserver images found"
