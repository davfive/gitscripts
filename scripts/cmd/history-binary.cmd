@echo off
rem history-binary.cmd
if "%~1"=="" (
  echo usage: history-binary.cmd ^<path^>
  exit /b 1
)
setlocal EnableDelayedExpansion
set "path=%~1"
echo ================================================================================
echo %path%: binary hash history
echo ================================================================================
for /f "delims=" %%H in ('git rev-list --all --objects -- "%path%" ^| findstr "%path%"') do (
  for /f "tokens=1" %%A in ("%%H") do echo %path%:%%A
)