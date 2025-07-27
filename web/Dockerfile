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

# Copy nginx configuration (Formspree endpoint will be injected from env variable at container runtime)
COPY nginx.conf /etc/nginx/nginx.conf

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8081/ || exit 1

# Set proper ownership
RUN chown -R nginx:nginx /usr/share/nginx/html

EXPOSE 8081

CMD ["nginx", "-g", "daemon off;"]
