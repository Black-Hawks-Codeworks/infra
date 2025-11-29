@echo off
REM Start self-hosted deployment environment (Windows .bat)

SET SCRIPT_DIR=%~dp0
SET COMPOSE_FILE=%SCRIPT_DIR%\docker-compose-selfhosted.yml
SET PROJECT_NAME=black-hawks-selfhosted

IF EXIST "%SCRIPT_DIR%\.env.localdev.secrets" (
  echo Sourcing secrets from %SCRIPT_DIR%\.env.localdev.secrets
  for /f "usebackq delims=" %%i in ("%SCRIPT_DIR%\.env.localdev.secrets") do set "%%i"
) ELSE IF EXIST "%SCRIPT_DIR%\.env.localdev" (
  echo Sourcing %SCRIPT_DIR%\.env.localdev
  for /f "usebackq delims=" %%i in ("%SCRIPT_DIR%\.env.localdev") do set "%%i"
) ELSE (
  echo Error: no secrets file found in %SCRIPT_DIR% >&2
  exit /b 1
)

IF "%CLOUDFLARE_TUNNEL_TOKEN%"=="" (
  echo Error: CLOUDFLARE_TUNNEL_TOKEN environment variable is not set! >&2
  echo Please add it to %SCRIPT_DIR%\.env.localdev.secrets or %SCRIPT_DIR%\.env.localdev >&2
  echo Get your tunnel token from: https://dash.cloudflare.com/ >&2
  exit /b 1
)

REM Bring down existing containers
echo Stopping existing containers...
docker compose -f "%COMPOSE_FILE%" -p %PROJECT_NAME% down

REM Start services in order: db → backend/frontend → cloudflared
echo Starting database...
docker compose -f "%COMPOSE_FILE%" -p %PROJECT_NAME% up -d db

echo Waiting for database to be ready...
timeout /t 5 /nobreak >nul

echo Starting backend and frontend...
docker compose -f "%COMPOSE_FILE%" -p %PROJECT_NAME% up -d backend frontend

echo Waiting for services to be ready...
timeout /t 5 /nobreak >nul

echo Starting Cloudflare Tunnel...
docker compose -f "%COMPOSE_FILE%" -p %PROJECT_NAME% up -d cloudflared

echo.
echo Self-hosted deployment started!
echo.
echo Services are running:
echo   - Database: PostgreSQL (internal)
echo   - Backend: http://localhost:3000
echo   - Frontend: http://localhost:5173
echo   - Cloudflare Tunnel: Running
echo.
echo Configure your Cloudflare Tunnel Public Hostnames in the dashboard:
echo   - Backend subdomain → http://localhost:3000
echo   - Frontend subdomain → http://localhost:5173
echo.
echo To view logs: docker compose -f %COMPOSE_FILE% -p %PROJECT_NAME% logs -f
echo To stop: docker compose -f %COMPOSE_FILE% -p %PROJECT_NAME% down
echo.
