#!/usr/bin/env bash

set -euo pipefail

print_help() {
    cat <<EOF
Usage: $0

This script starts the application in local development mode using:
- docker-compose-localdev.yml
- compose project name: black-hawks

It sources environment variables from ./infra/.env.localdev. The script removes the named backend and frontend node_modules
volume so a rebuilt container will pick up dependency changes.

Options:
  -h, --help   Show this help message and exit
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_help
  exit 0
fi

# Always dev for this script
# Resolve paths relative to the script location so the script can be run from repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose-localdev.yml"
COMPOSE_PROJECT_NAME=black-hawks
ENV_FILE="$SCRIPT_DIR/.env.localdev"

echo "Sourcing environment from $ENV_FILE"
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# Bring down existing containers and remove backend and frontend node_modules named volumes
docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" down && \
  ( docker volume rm "${COMPOSE_PROJECT_NAME}_backend_node_modules" || true ) && \
  ( docker volume rm "${COMPOSE_PROJECT_NAME}_frontend_node_modules" || true ) && \
  docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up --build
