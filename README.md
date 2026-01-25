# Infra

Here is the DB and the scripts to start the containers for the backend and the database. In an attempt to avoid increasing the complexity
of the project we abandoned the postgres sql in favor of [LowDb](https://www.npmjs.com/package/lowdb-node)(more in backend), which made the project more complex :p. So,
although the db exists in this repo it is not completed.

## Local development (Linux / macOS / Windows)

There are helper scripts to start the local development environment (Postgres + backend, and later frontend) using Docker Compose.

Files:

- `start-localdev.sh` - POSIX shell script (Linux). Run from repo root as `./start-localdev.sh`.
- `start-localdev.bat` - Windows batch script. Run in Command Prompt as `start-localdev.bat`.
- selfhosted-startup.sh - Linux(bash) script. To selfhost the project using cloudflared container
- selfhosted-startup.bat - Windows(shell) script. To selfhost the project using _cloudflared_ container

All scripts:

- Source secrets from `.env.localdev`.
- Use the Docker Compose project name `black-hawks-portal`.
- Remove the named volume `black-hawks-portal_backend_node_modules` before bringing services up to ensure dependency changes are applied.

Usage examples:

Linux/macOS (preferred):

```bash
./start-localdev.sh
```

Windows:

Open Command Prompt in the repo root and run:

```bash
.\start-localdev.bat
```

If you prefer to run docker compose manually from the repo root:

```bash
docker compose -f infra/docker-compose-localdev.yml -p black-hawks-portal up --build
```
