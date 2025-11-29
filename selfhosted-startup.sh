#!/usr/bin/env bash

set -euo pipefail

print_help() {
    cat <<EOF
Usage: $0

This script starts the application in self-hosted deployment mode using:
- docker-compose-selfhosted.yml
- compose project name: black-hawks-selfhosted

It sources secrets from ./infra/.env.localdev.secrets if present, otherwise falls
back to ./infra/.env.localdev. The script requires CLOUDFLARE_TUNNEL_TOKEN to be
set in the secrets file.

Options:
  -h, --help   Show this help message and exit

Example:
  $0
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_help
  exit 0
fi

# Resolve paths relative to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose-selfhosted.yml"
COMPOSE_PROJECT_NAME=black-hawks-selfhosted
SECRETS_FILE="$SCRIPT_DIR/.env.localdev.secrets"

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

# Check if Cloudflare Tunnel token is set
if [[ -z "${CLOUDFLARE_TUNNEL_TOKEN:-}" ]]; then
  echo "Error: CLOUDFLARE_TUNNEL_TOKEN environment variable is not set!" >&2
  echo "Please add it to $SECRETS_FILE or $SCRIPT_DIR/.env.localdev" >&2
  echo "Get your tunnel token from: https://dash.cloudflare.com/" >&2
  exit 1
fi

# Export tunnel token for docker-compose
export CLOUDFLARE_TUNNEL_TOKEN

# Bring down existing containers
echo "Stopping existing containers..."
docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" down || true

# Start services in order: db → backend/frontend → cloudflared
echo "Starting database..."
docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d db

echo "Waiting for database to be ready..."
sleep 5

echo "Starting backend and frontend..."
docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d backend frontend

echo "Waiting for services to be ready..."
sleep 5

echo "Starting Cloudflare Tunnel..."
docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d cloudflared

echo ""
echo "Self-hosted deployment started!"
echo ""
echo "Services are running:"
echo "  - Database: PostgreSQL (internal)"
echo "  - Backend: http://localhost:3000"
echo "  - Frontend: http://localhost:5173"
echo "  - Cloudflare Tunnel: Running"
echo ""
echo "Configure your Cloudflare Tunnel Public Hostnames in the dashboard:"
echo "  - Backend subdomain → http://localhost:3000"
echo "  - Frontend subdomain → http://localhost:5173"
echo ""
echo "To view logs: docker compose -f $DOCKER_COMPOSE_FILE -p $COMPOSE_PROJECT_NAME logs -f"
echo "To stop: docker compose -f $DOCKER_COMPOSE_FILE -p $COMPOSE_PROJECT_NAME down"
echo ""
