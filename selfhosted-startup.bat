@echo off
REM Start self-hosted deployment environment (Windows .bat)

SET SCRIPT_DIR=%~dp0
SET COMPOSE_FILE=%SCRIPT_DIR%\docker-compose-selfhosted.yml
SET PROJECT_NAME=black-hawks-selfhosted

echo Sourcing environment from %SCRIPT_DIR%\.env.localhost
for /f "usebackq delims=" %%i in ("%SCRIPT_DIR%\.env.localhost") do set "%%i"

IF "%CLOUDFLARE_TUNNEL_TOKEN%"=="" (
  echo Error: CLOUDFLARE_TUNNEL_TOKEN environment variable is not set! >&2
  echo Please add it to %SCRIPT_DIR%\.env.localhost >&2
  echo Get your tunnel token from: https://dash.cloudflare.com/ >&2
  exit /b 1
)

REM Bring down existing stack and bring up with build
docker compose -f "%COMPOSE_FILE%" -p %PROJECT_NAME% down
docker compose -f "%COMPOSE_FILE%" -p %PROJECT_NAME% up --build
