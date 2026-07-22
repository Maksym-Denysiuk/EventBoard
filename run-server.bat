@echo off
cd /d "%~dp0"
echo Starting EventBoard server at http://localhost:8000 ...
start "" "http://localhost:8000/index.html"
powershell -NoProfile -ExecutionPolicy Bypass -File ".claude\serve.ps1"
