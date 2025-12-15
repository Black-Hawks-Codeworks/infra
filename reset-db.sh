#!/usr/bin/env bash

set -euo pipefail

print_help() {
    cat <<EOF
Usage: $0

This script deletes the database volume for the local development environment.
This allows you to easily re-seed the database by running the startup script again.

The script will:
- Stop containers if running
- Remove the black-hawks_db-data volume

Options:
  -h, --help   Show this help message and exit
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_help
  exit 0
fi

# Resolve paths relative to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose-localdev-full.yml"
COMPOSE_PROJECT_NAME=black-hawks
DB_VOLUME_NAME="${COMPOSE_PROJECT_NAME}_db-data"

echo "Stopping containers..."
docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" down || true

echo "Removing database volume: $DB_VOLUME_NAME"
docker volume rm "$DB_VOLUME_NAME" 2>/dev/null || echo "Volume $DB_VOLUME_NAME does not exist (already removed or never created)"

echo "Database volume reset complete. Run localdev-startup.sh to recreate the database with fresh data."
