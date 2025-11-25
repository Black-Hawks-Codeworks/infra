#!/usr/bin/env bash

set -euo pipefail

print_help() {
    cat <<EOF
Usage: $0 [DOMAIN_NAME] [CERTBOT_EMAIL]

This script starts the application in self-hosted deployment mode using:
- docker-compose-selfhosted.yml
- compose project name: black-hawks-selfhosted

It sources secrets from ./infra/.env.localdev.secrets if present, otherwise falls
back to ./infra/.env.localdev. The script handles SSL certificate generation
using certbot for the specified domain.

Arguments:
  DOMAIN_NAME     Your domain name (e.g., example.com) - REQUIRED
  CERTBOT_EMAIL   Email for Let's Encrypt notifications (default: admin@example.com)

Options:
  -h, --help   Show this help message and exit

Example:
  $0 example.com admin@example.com
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_help
  exit 0
fi

if [[ -z "${1:-}" ]]; then
  echo "Error: DOMAIN_NAME is required" >&2
  print_help
  exit 1
fi

DOMAIN_NAME="$1"
CERTBOT_EMAIL="${2:-admin@example.com}"

# Resolve paths relative to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose-selfhosted.yml"
COMPOSE_PROJECT_NAME=black-hawks-selfhosted
SECRETS_FILE="$SCRIPT_DIR/.env.localdev.secrets"
NGINX_CONF="$SCRIPT_DIR/nginx/nginx.conf"
NGINX_CONF_HTTP_ONLY="$SCRIPT_DIR/nginx/nginx.conf.http-only"
NGINX_CONF_WITH_SSL="$SCRIPT_DIR/nginx/nginx.conf.with-ssl"

if [[ -f "$SECRETS_FILE" ]]; then
  echo "Sourcing secrets from $SECRETS_FILE"
  set -a
  # shellcheck source=/dev/null
  source "$SECRETS_FILE"
  set +a
elif [[ -f "$SCRIPT_DIR/.env.localdev" ]]; then
  echo "Secrets file not found, sourcing $SCRIPT_DIR/.env.localdev"
  set -a
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/.env.localdev"
  set +a
else
  echo "Error: no secrets file found (tried $SECRETS_FILE and $SCRIPT_DIR/.env.localdev)" >&2
  exit 1
fi

# Export domain name and certbot email for docker-compose
export DOMAIN_NAME
export CERTBOT_EMAIL

# Function to generate nginx config with SSL
generate_nginx_ssl_config() {
  local domain="$1"
  cat > "$NGINX_CONF_WITH_SSL" <<EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    sendfile on;
    keepalive_timeout 65;

    # HTTP server - redirect to HTTPS
    server {
        listen 80;
        server_name _;

        # Let's Encrypt certificate validation
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        # Redirect all other HTTP traffic to HTTPS
        location / {
            return 301 https://\$host\$request_uri;
        }
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name _;

        # SSL certificate configuration (Let's Encrypt)
        ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;

        # SSL configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # Security headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # Proxy API requests to backend
        location /api/ {
            proxy_pass http://backend:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
        }

        # Proxy all other requests to frontend dev server
        location / {
            proxy_pass http://frontend:5173;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
            
            # WebSocket support for Vite HMR
            proxy_read_timeout 86400;
        }
    }
}
EOF
}

# Check if certificates already exist
CERT_PATH="/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem"
if docker volume inspect "${COMPOSE_PROJECT_NAME}_certbot-etc" >/dev/null 2>&1; then
  if docker run --rm -v "${COMPOSE_PROJECT_NAME}_certbot-etc:/etc/letsencrypt:ro" alpine test -f "$CERT_PATH" 2>/dev/null; then
    echo "SSL certificates already exist for $DOMAIN_NAME"
    CERT_EXISTS=true
  else
    CERT_EXISTS=false
  fi
else
  CERT_EXISTS=false
fi

# Use HTTP-only config initially (current nginx.conf serves HTTP)
# If certificates exist, switch to SSL config
if [[ "$CERT_EXISTS" == "true" ]]; then
  echo "Updating nginx config for SSL with domain: $DOMAIN_NAME"
  generate_nginx_ssl_config "$DOMAIN_NAME"
  cp "$NGINX_CONF_WITH_SSL" "$NGINX_CONF"
else
  echo "SSL certificates not found. Nginx will serve HTTP only initially."
fi

# Bring down existing containers
echo "Stopping existing containers..."
docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" down || true

# Start services without certbot first (nginx will serve HTTP)
echo "Starting services..."
docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d db backend frontend nginx

# Wait for nginx to be ready
echo "Waiting for nginx to be ready..."
sleep 5

# Generate SSL certificates if they don't exist
if [[ "$CERT_EXISTS" == "false" ]]; then
  echo "Generating SSL certificates for $DOMAIN_NAME using Cloudflare DNS challenge..."
  
  # Check if Cloudflare API token is set
  if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
    echo "Error: CLOUDFLARE_API_TOKEN environment variable is not set!" >&2
    echo "Please add it to $SECRETS_FILE or $SCRIPT_DIR/.env.localdev" >&2
    echo "Get your token from: https://dash.cloudflare.com/profile/api-tokens" >&2
    exit 1
  fi
  
  echo "Using Cloudflare DNS challenge (works behind CGNAT, no port 80/443 needed)"
  echo "Press Enter to continue or Ctrl+C to cancel..."
  read -r
  
  # Create temporary credentials file for certbot
  CLOUDFLARE_CREDENTIALS_FILE=$(mktemp)
  echo "dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN" > "$CLOUDFLARE_CREDENTIALS_FILE"
  chmod 600 "$CLOUDFLARE_CREDENTIALS_FILE"
  
  if docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" run --rm \
    -v "$CLOUDFLARE_CREDENTIALS_FILE:/tmp/cloudflare.ini:ro" \
    certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials /tmp/cloudflare.ini \
    --dns-cloudflare-propagation-seconds 60 \
    --email "$CERTBOT_EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DOMAIN_NAME"; then
    
    # Clean up credentials file
    rm -f "$CLOUDFLARE_CREDENTIALS_FILE"
    echo "Certificates generated successfully. Updating nginx config..."
    
    # Generate and apply SSL config
    generate_nginx_ssl_config "$DOMAIN_NAME"
    cp "$NGINX_CONF_WITH_SSL" "$NGINX_CONF"
    
    # Restart nginx to pick up SSL configuration
    echo "Restarting nginx with SSL configuration..."
    docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" restart nginx
  else
    # Clean up credentials file on error
    rm -f "$CLOUDFLARE_CREDENTIALS_FILE"
    echo "Warning: Certificate generation failed. Continuing with HTTP only..." >&2
    echo "You can run certbot manually later to generate certificates." >&2
  fi
fi

echo ""
echo "Self-hosted deployment started!"
if [[ "$CERT_EXISTS" == "true" ]] || docker run --rm -v "${COMPOSE_PROJECT_NAME}_certbot-etc:/etc/letsencrypt:ro" alpine test -f "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" 2>/dev/null; then
  echo "Frontend: https://$DOMAIN_NAME"
  echo "Backend API: https://$DOMAIN_NAME/api"
else
  echo "Frontend: http://$DOMAIN_NAME"
  echo "Backend API: http://$DOMAIN_NAME/api"
  echo "Note: SSL certificates not configured. Run certbot manually to enable HTTPS."
fi
echo ""
echo "To view logs: docker compose -f $DOCKER_COMPOSE_FILE -p $COMPOSE_PROJECT_NAME logs -f"
echo "To stop: docker compose -f $DOCKER_COMPOSE_FILE -p $COMPOSE_PROJECT_NAME down"
