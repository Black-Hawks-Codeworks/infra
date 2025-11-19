#!/usr/bin/env bash
set -euo pipefail

# macOS double-clickable script (executable .command)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose-localdev.yml"
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

docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" down && \
  ( docker volume rm "${COMPOSE_PROJECT_NAME}_backend_node_modules" || true ) && \
  docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up --build
