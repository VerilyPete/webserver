#!/bin/bash
# Add Nginx configuration to secrets management

echo "ADDING NGINX SECRETS MANAGEMENT"
echo "==============================="

cd ~/webserver

echo "1. Creating nginx.conf template with placeholder..."
cat > web/nginx.conf.template << 'EOF'
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       8081;
        #listen       [::]:80;
        server_name  localhost;
        root         /usr/share/nginx/html/src;

        # Formspree proxy endpoint (with templated endpoint)
        location /submit-form {
            proxy_pass __FORMSPREE_ENDPOINT__;
            proxy_set_header Host formspree.io;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header Origin https://peterhollmer.com;
            proxy_set_header Referer https://peterhollmer.com/;
            proxy_ssl_verify off;
            proxy_ssl_server_name on;
            proxy_ssl_protocols TLSv1.2 TLSv1.3;
        }

        # Cache static files
        location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            add_header Vary "Accept-Encoding";
        }

        # Cache HTML files for shorter time
        location ~* \.html$ {
            expires 1h;
            add_header Cache-Control "public, max-age=3600";
        }

        # Error pages
        error_page 404 /404.html;
        location = /404.html {
            root /usr/share/nginx/html/src;
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /usr/share/nginx/html/src;
        }

        # Default location (must be last)
        location / {
            try_files $uri $uri/ =404;
            expires 1h;
            add_header Cache-Control "public, max-age=3600";
        }

        # Load configuration files for the default server block
        include /etc/nginx/default.d/*.conf;
    }

    # Settings for a TLS enabled server.
    #
    #    server {
    #        listen       443 ssl http2;
    #        listen       [::]:443 ssl http2;
    #        server_name  _;
    #        root         /usr/share/nginx/html;
    #
    #        ssl_certificate "/etc/pki/nginx/server.crt";
    #        ssl_certificate_key "/etc/pki/nginx/private/server.key";
    #        ssl_session_cache shared:SSL:1m;
    #        ssl_session_timeout  10m;
    #        ssl_ciphers PROFILE=SYSTEM;
    #        ssl_prefer_server_ciphers on;
    #
    #        # Load configuration files for the default server block.
    #        include /etc/nginx/default.d/*.conf;
    #
    #        error_page 404 /404.html;
    #            location = /40x.html {
    #        }
    #
    #        error_page 500 502 503 504 /50x.html;
    #            location = /50x.html {
    #        }
    #    }

}
EOF

echo "2. Backing up current nginx.conf and extracting Formspree endpoint..."
if [ -f web/nginx.conf ]; then
    cp web/nginx.conf web/nginx.conf.backup
    
    # Extract the actual Formspree endpoint
    FORMSPREE_ENDPOINT=$(grep "proxy_pass" web/nginx.conf | head -1 | sed 's/.*proxy_pass \(.*\);/\1/')
    echo "Found Formspree endpoint: $FORMSPREE_ENDPOINT"
    
    # Replace current nginx.conf with template
    cp web/nginx.conf.template web/nginx.conf
    echo "✅ Replaced nginx.conf with template version"
else
    echo "⚠️  nginx.conf not found, using template as-is"
    cp web/nginx.conf.template web/nginx.conf
    FORMSPREE_ENDPOINT="https://formspree.io/f/YOUR_FORM_ID"
fi

echo "3. Adding Formspree endpoint to .env placeholders..."
if ! grep -q "FORMSPREE_ENDPOINT" .env; then
    cat >> .env << 'EOF'

# ===============================
# FORMSPREE CONFIGURATION
# ===============================
# Your Formspree form endpoint
FORMSPREE_ENDPOINT=__FORMSPREE_ENDPOINT__
EOF
fi

echo "4. Updating secret injection script to handle nginx.conf..."
cat > scripts/inject-secrets.sh << 'EOF'
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
sed -i "s/__GITHUB_TOKEN__/${GITHUB_TOKEN}/" .env
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
EOF

echo "5. Updating Containerfile to use nginx.conf from build context..."
cat > web/Containerfile << 'EOF'
FROM nginx:alpine

# Install git for cloning website content during build
RUN apk add --no-cache git curl

# Clone website content during container build
ARG REPO_URL=https://github.com/VerilyPete/peterhollmer.com.git
ARG REPO_BRANCH=main

# Clone the repository and copy src contents to nginx html directory
RUN git clone --depth 1 --branch ${REPO_BRANCH} ${REPO_URL} /tmp/website && \
    mkdir -p /usr/share/nginx/html/src && \
    if [ -d "/tmp/website/src" ]; then \
        cp -r /tmp/website/src/* /usr/share/nginx/html/src/; \
    else \
        cp -r /tmp/website/* /usr/share/nginx/html/src/; \
    fi && \
    rm -rf /tmp/website

# Create default index page as fallback
RUN if [ ! -f /usr/share/nginx/html/src/index.html ]; then \
        echo '<h1>Containerized Web Server</h1><p>Website content will be here</p>' > /usr/share/nginx/html/src/index.html; \
    fi

# Copy nginx configuration (will be processed by inject-secrets script before build)
COPY nginx.conf /etc/nginx/nginx.conf

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8081/ || exit 1

# Set proper ownership
RUN chown -R nginx:nginx /usr/share/nginx/html

EXPOSE 8081

CMD ["nginx", "-g", "daemon off;"]
EOF

echo "6. Updating build script to inject secrets before building..."
cat > scripts/build.sh << 'EOF'
#!/bin/bash
set -e
cd ~/webserver

echo "Building web container with website content..."

# Preserve exported environment variables
EXPORTED_PUSH_TO_REGISTRY="${PUSH_TO_REGISTRY}"
EXPORTED_GITHUB_TOKEN="${GITHUB_TOKEN}"
EXPORTED_FORMSPREE_ENDPOINT="${FORMSPREE_ENDPOINT}"

# Load environment variables from .env
if [ -f .env ]; then
    source .env
fi

# Restore exported variables if they were set
if [ -n "${EXPORTED_PUSH_TO_REGISTRY}" ]; then
    PUSH_TO_REGISTRY="${EXPORTED_PUSH_TO_REGISTRY}"
fi

if [ -n "${EXPORTED_GITHUB_TOKEN}" ] && [ "${EXPORTED_GITHUB_TOKEN}" != "__GITHUB_TOKEN__" ]; then
    GITHUB_TOKEN="${EXPORTED_GITHUB_TOKEN}"
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
    if [ -n "${GITHUB_TOKEN}" ] && [ "${GITHUB_TOKEN}" != "__GITHUB_TOKEN__" ]; then
        echo "${GITHUB_TOKEN}" | podman login ${REGISTRY} -u ${USERNAME} --password-stdin
        
        # Push images
        podman push ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${TAG}
        podman push ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${LATEST_TAG}
        
        echo "✅ Images pushed to registry:"
        echo "   ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${TAG}"
        echo "   ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${LATEST_TAG}"
    else
        echo "❌ GITHUB_TOKEN not set or is placeholder, cannot push to registry"
        exit 1
    fi
else
    echo "Local build complete. To push to registry:"
    echo "  export PUSH_TO_REGISTRY=true"
    echo "  export GITHUB_TOKEN=your-github-token"
    echo "  export FORMSPREE_ENDPOINT=https://formspree.io/f/your-form-id"
    echo "  ./scripts/build.sh"
fi

echo ""
echo "Images built:"
podman images | grep -E "(webserver|ghcr.io)" || echo "No webserver images found"
EOF

echo "7. Updating GitHub Actions workflow to include Formspree endpoint..."
if [ -f .github/workflows/deploy-production.yml ]; then
    sed -i '/export SERVER_HOST=/a\          export FORMSPREE_ENDPOINT="${{ secrets.FORMSPREE_ENDPOINT }}"' .github/workflows/deploy-production.yml
fi

echo ""
echo "NGINX SECRETS MANAGEMENT COMPLETE!"
echo "================================="
echo ""
if [ -n "$FORMSPREE_ENDPOINT" ]; then
echo "✅ Found your Formspree endpoint: $FORMSPREE_ENDPOINT"
echo ""
echo "Add this to your GitHub Secrets:"
echo "FORMSPREE_ENDPOINT=$FORMSPREE_ENDPOINT"
fi
echo ""
echo "Files created/updated:"
echo "✅ web/nginx.conf.template - Template with placeholder"
echo "✅ web/nginx.conf - Now uses placeholder (safe to commit)"
echo "✅ scripts/inject-secrets.sh - Handles nginx.conf processing"
echo "✅ scripts/build.sh - Injects secrets before building"
echo "✅ .env - Added Formspree placeholder"
echo ""
echo "Next steps:"
echo "1. Add to GitHub Secrets: FORMSPREE_ENDPOINT=https://formspree.io/f/your-form-id"
echo "2. Test local build:"
echo "   export FORMSPREE_ENDPOINT=https://formspree.io/f/your-form-id"
echo "   ./scripts/build.sh"
