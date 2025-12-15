@echo off
REM Reset local development database by deleting the database volume (Windows .bat)

SET SCRIPT_DIR=%~dp0
SET COMPOSE_FILE=%SCRIPT_DIR%\docker-compose-localdev-full.yml
SET PROJECT_NAME=black-hawks
SET DB_VOLUME_NAME=%PROJECT_NAME%_db-data

echo Stopping containers...
docker compose -f "%COMPOSE_FILE%" -p %PROJECT_NAME% down 2>nul || echo Containers already stopped or not running

echo Removing database volume: %DB_VOLUME_NAME%
docker volume rm %DB_VOLUME_NAME% 2>nul || echo Volume %DB_VOLUME_NAME% does not exist (already removed or never created)

echo Database volume reset complete. Run localdev-startup.bat to recreate the database with fresh data.
