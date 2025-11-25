@echo off
REM Start self-hosted deployment environment (Windows .bat)

SET SCRIPT_DIR=%~dp0
SET COMPOSE_FILE=%SCRIPT_DIR%\docker-compose-selfhosted.yml
SET PROJECT_NAME=black-hawks-selfhosted
SET NGINX_CONF=%SCRIPT_DIR%\nginx\nginx.conf

IF "%1"=="" (
  echo Error: DOMAIN_NAME is required
  echo Usage: %0 DOMAIN_NAME [CERTBOT_EMAIL]
  echo Example: %0 example.com admin@example.com
  exit /b 1
)

SET DOMAIN_NAME=%1
SET CERTBOT_EMAIL=%2
IF "%CERTBOT_EMAIL%"=="" SET CERTBOT_EMAIL=admin@example.com

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

REM Bring down existing containers
echo Stopping existing containers...
docker compose -f "%COMPOSE_FILE%" -p %PROJECT_NAME% down

REM Start services without certbot first
echo Starting services...
docker compose -f "%COMPOSE_FILE%" -p %PROJECT_NAME% up -d db backend frontend nginx

REM Wait for nginx to be ready
echo Waiting for nginx to be ready...
timeout /t 5 /nobreak >nul

REM Generate SSL certificates
echo Generating SSL certificates for %DOMAIN_NAME%...
echo Make sure your domain %DOMAIN_NAME% points to this server's IP address!
pause

docker compose -f "%COMPOSE_FILE%" -p %PROJECT_NAME% run --rm certbot certonly --webroot --webroot-path=/var/www/certbot --email %CERTBOT_EMAIL% --agree-tos --no-eff-email -d %DOMAIN_NAME%
IF %ERRORLEVEL% EQU 0 (
  echo Certificates generated successfully.
  echo.
  echo NOTE: You need to manually update %NGINX_CONF% to enable SSL.
  echo Copy the SSL server block from nginx.conf.template and update the domain name.
  echo Then restart nginx: docker compose -f "%COMPOSE_FILE%" -p %PROJECT_NAME% restart nginx
) ELSE (
  echo Warning: Certificate generation failed. Continuing with HTTP only...
  echo You can run certbot manually later to generate certificates.
)

echo.
echo Self-hosted deployment started!
echo Frontend: http://%DOMAIN_NAME%
echo Backend API: http://%DOMAIN_NAME%/api
echo.
echo To view logs: docker compose -f %COMPOSE_FILE% -p %PROJECT_NAME% logs -f
echo To stop: docker compose -f %COMPOSE_FILE% -p %PROJECT_NAME% down
