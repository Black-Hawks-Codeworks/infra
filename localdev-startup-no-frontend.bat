@echo off
REM Start local development environment (Windows .bat)

SET SCRIPT_DIR=%~dp0
SET COMPOSE_FILE=%SCRIPT_DIR%\docker-compose-localdev-no-frontend.yml
SET PROJECT_NAME=black-hawks-portal

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

REM Bring down existing stack, remove backend_node_modules volume, and bring up
docker compose -f "%COMPOSE_FILE%" -p %PROJECT_NAME% down
docker volume rm "%PROJECT_NAME%_backend_node_modules" 2>nul || echo Ignoring missing volume
docker compose -f "%COMPOSE_FILE%" -p %PROJECT_NAME% up --build
