#!/usr/bin/env bash

set -euo pipefail

print_help() {
    cat <<EOF
Usage: $0

This script starts the application in self-hosted deployment mode using:
- docker-compose-selfhosted.yml
- compose project name: black-hawks-selfhosted

It sources environment variables from ./infra/.env.localhost. The script requires
CLOUDFLARE_TUNNEL_TOKEN to be set in the environment file.

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
ENV_FILE="$SCRIPT_DIR/.env.localdev"

echo "Sourcing environment from $ENV_FILE"
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# Check if Cloudflare Tunnel token is set
if [[ -z "${CLOUDFLARE_TUNNEL_TOKEN:-}" ]]; then
  echo "Error: CLOUDFLARE_TUNNEL_TOKEN environment variable is not set!" >&2
  echo "Please add it to $ENV_FILE" >&2
  echo "Get your tunnel token from: https://dash.cloudflare.com/" >&2
  exit 1
fi

# Export tunnel token for docker-compose
export CLOUDFLARE_TUNNEL_TOKEN

# Bring down existing containers and bring up with build
docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" down && \
  docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up --build
