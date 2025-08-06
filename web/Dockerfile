FROM nginx:alpine

# Install git for cloning website content during build
RUN apk add --no-cache git curl

# Clone website content during container build
ARG REPO_URL=https://github.com/VerilyPete/peterhollmer.com.git
ARG COMMIT_SHA

RUN set -e && \
    rm -rf /usr/share/nginx/html/* && \
    if [ -z "${COMMIT_SHA}" ]; then \
    git clone --depth=1 --branch main ${REPO_URL} /usr/share/nginx/html; \
    else \
    git clone ${REPO_URL} /usr/share/nginx/html && \
    cd /usr/share/nginx/html && \
    git fetch origin && \
    git checkout ${COMMIT_SHA}; \
    fi && \
    rm -rf /usr/share/nginx/html/.git

# Create default index page as fallback
RUN if [ ! -f /usr/share/nginx/html/src/index.html ]; then \
    mkdir -p /usr/share/nginx/html/src && \
    echo '<h1>Containerized Web Server</h1><p>Website content will be here</p>' > /usr/share/nginx/html/src/index.html; \
    fi

# Copy nginx configuration (Formspree endpoint will be injected from env variable at container runtime)
COPY nginx.conf /etc/nginx/nginx.conf

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8081/ || exit 1

# Set proper ownership
RUN chown -R nginx:nginx /usr/share/nginx/html

EXPOSE 8081

CMD ["nginx", "-g", "daemon off;"]
