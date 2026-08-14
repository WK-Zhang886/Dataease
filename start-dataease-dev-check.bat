@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0dev\start-dataease-dev.ps1" -CheckOnly
