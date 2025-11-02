# Infra

Here is the DB and the scripts to start the containers for the backend and the database

## Local development (Linux / macOS / Windows)

There are helper scripts to start the local development environment (Postgres + backend) using Docker Compose.

Files:

- `start-localdev.sh` - POSIX shell script (Linux). Run from repo root as `./start-localdev.sh`.
- `start-localdev.command` - macOS double-clickable script (executable). Run with `./start-localdev.command` or double-click in Finder.
- `start-localdev.bat` - Windows batch script. Run in Command Prompt as `start-localdev.bat`.

All scripts:

- Use the compose file `docker-compose-localdev.yml`.
- Source secrets from `.env.localdev.secrets` if present, otherwise fall back to `.env.localdev`.
- Use the Docker Compose project name `black-hawks-portal`.
- Remove the named volume `black-hawks-portal_backend_node_modules` before bringing services up to ensure dependency changes are applied.

Usage examples:

Linux/macOS (preferred):

```bash
./start-localdev.sh
```

macOS double-click:

Make `start-localdev.command` executable then double-click it in Finder.

Windows:

Open Command Prompt in the repo root and run:

```
infra\\start-localdev.bat
```

If you prefer to run docker compose manually from the repo root:

```bash
docker compose -f infra/docker-compose-localdev.yml -p black-hawks-portal up --build
```
