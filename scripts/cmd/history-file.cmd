@echo off
rem history-file.cmd
if "%~1"=="" (
  echo usage: history-file.cmd ^<path^>
  exit /b 1
)
setlocal EnableDelayedExpansion
set "path=%~1"
for /f "delims=" %%H in ('git rev-list --all --objects -- "%path%" ^| findstr "%path%"') do (
  for /f "tokens=1" %%A in ("%%H") do (
    echo ================================================================================
    echo cat-file %path%:%%A
    echo ================================================================================
    git cat-file -p %%A
  )
)