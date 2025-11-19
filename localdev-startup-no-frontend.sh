#!/usr/bin/env bash

set -euo pipefail

print_help() {
    cat <<EOF
Usage: $0

This script starts the application in local development mode using:
- docker-compose-localdev-no-frontend.yml
- compose project name: black-hawks-portal

It sources secrets from ./infra/.env.localdev.secrets if present, otherwise falls
back to ./infra/.env.localdev. The script removes the named backend node_modules
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
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose-localdev-no-frontend.yml"
COMPOSE_PROJECT_NAME=black-hawks-portal
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

# Bring down existing containers and remove backend node_modules named volume
docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" down && \
  ( docker volume rm "${COMPOSE_PROJECT_NAME}_backend_node_modules" || true ) && \
  docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up --build
