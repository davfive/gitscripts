@echo off
rem Unified cmd runner — updated for new layout
if "%~1"=="" (
  echo Usage: git gs ^<script-name^> [args...]
  exit /b 2
)
setlocal EnableDelayedExpansion

set "script=%~1"
shift

rem find repo root
for /f "delims=" %%R in ('git rev-parse --show-toplevel 2^>nul') do set "repo=%%R"
if not defined repo (
  echo Not a git repository>&2
  exit /b 2
)

set "found="
if exist "%repo%\gitscripts\scripts\cmd\%script%.cmd" set "found=%repo%\gitscripts\scripts\cmd\%script%.cmd"
if not defined found if exist "%repo%\gitscripts\scripts\cmd\%script%.bat" set "found=%repo%\gitscripts\scripts\cmd\%script%.bat"
if not defined found if exist "%repo%\gitscripts\scripts\ps1\%script%.ps1" set "found=%repo%\gitscripts\scripts\ps1\%script%.ps1"
if not defined found if exist "%repo%\gitscripts\scripts\sh\%script%.sh" set "found=%repo%\gitscripts\scripts\sh\%script%.sh"
if not defined found if exist "%repo%\gitscripts\%script%" set "found=%repo%\gitscripts\%script%"
if not defined found if exist "%repo%\gitscripts\%script%.cmd" set "found=%repo%\gitscripts\%script%.cmd"
if not defined found if exist "%repo%\gitscripts\%script%.bat" set "found=%repo%\gitscripts\%script%.bat"
if not defined found if exist "%repo%\gitscripts\%script%.ps1" set "found=%repo%\gitscripts\%script%.ps1"
if not defined found if exist "%repo%\gitscripts\%script%.sh" set "found=%repo%\gitscripts\%script%.sh"
if not defined found if exist "%repo%\gitscripts\user-scripts-untracked\%script%" set "found=%repo%\gitscripts\user-scripts-untracked\%script%"
if not defined found if exist "%repo%\gitscripts\user-scripts-untracked\%script%.cmd" set "found=%repo%\gitscripts\user-scripts-untracked\%script%.cmd"
if not defined found if exist "%repo%\gitscripts\user-scripts-untracked\%script%.bat" set "found=%repo%\gitscripts\user-scripts-untracked\%script%.bat"
if not defined found if exist "%repo%\gitscripts\user-scripts-untracked\%script%.ps1" set "found=%repo%\gitscripts\user-scripts-untracked\%script%.ps1"
if not defined found if exist "%repo%\gitscripts\user-scripts-untracked\%script%.sh" set "found=%repo%\gitscripts\user-scripts-untracked\%script%.sh"

if not defined found (
  echo Script not found: %script%>&2
  echo Run 'git gs --help' to list available commands.
  exit /b 127
)

rem Dispatch
set "ext=%found:~-4%"
if /i "%ext%"==".ps1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%found%" %*
  exit /b %ERRORLEVEL%
)
if /i "%ext%"==".cmd" (
  call "%found%" %*
  exit /b %ERRORLEVEL%
)
if /i "%ext%"==".bat" (
  call "%found%" %*
  exit /b %ERRORLEVEL%
)
if /i "%ext%"==".sh" (
  bash "%found%" %*
  exit /b %ERRORLEVEL%
)

call "%found%" %*
exit /b %ERRORLEVEL%
endlocal