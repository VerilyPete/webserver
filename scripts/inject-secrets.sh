#!/bin/bash
# Inject secrets from environment variables into .env file and nginx.conf

set -e

echo "INJECTING SECRETS FROM ENVIRONMENT"
echo "=================================="

cd ~/webserver

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    exit 1
fi

echo "Replacing placeholders in .env with environment variables..."

# Create backup
cp .env .env.backup

# Replace placeholders with environment variables
sed -i "s/__TAILSCALE_AUTH_KEY__/${TAILSCALE_AUTH_KEY}/" .env
sed -i "s/__HOSTNAME__/${HOSTNAME}/" .env
sed -i "s/__CLOUDFLARE_TUNNEL_TOKEN__/${CLOUDFLARE_TUNNEL_TOKEN}/" .env
sed -i "s/__GHCR_TOKEN__/${GHCR_TOKEN}/" .env
sed -i "s/__SERVER_HOST__/${SERVER_HOST}/" .env
sed -i "s|__FORMSPREE_ENDPOINT__|${FORMSPREE_ENDPOINT}|" .env

echo "✅ Secrets injected into .env"

# Handle nginx.conf template
if [ -f web/nginx.conf.template ]; then
    echo "Processing nginx.conf template..."
    
    # Create nginx.conf from template with Formspree endpoint
    sed "s|__FORMSPREE_ENDPOINT__|${FORMSPREE_ENDPOINT}|g" web/nginx.conf.template > web/nginx.conf
    
    echo "✅ nginx.conf generated from template with Formspree endpoint"
else
    echo "⚠️  nginx.conf.template not found, using existing nginx.conf"
fi

# Validate that all placeholders were replaced
echo "Checking for remaining placeholders..."
REMAINING_PLACEHOLDERS=0

if grep -q "__.*__" .env; then
    echo "⚠️  Remaining placeholders in .env:"
    grep "__.*__" .env || true
    REMAINING_PLACEHOLDERS=1
fi

if [ -f web/nginx.conf ] && grep -q "__.*__" web/nginx.conf; then
    echo "⚠️  Remaining placeholders in nginx.conf:"
    grep "__.*__" web/nginx.conf || true
    REMAINING_PLACEHOLDERS=1
fi

if [ $REMAINING_PLACEHOLDERS -eq 0 ]; then
    echo "✅ All placeholders successfully replaced"
else
    echo "❌ Some placeholders were not replaced"
    exit 1
fi
