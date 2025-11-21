@echo off
rem add-select.cmd
setlocal EnableDelayedExpansion
if "%~1" neq "" (
  echo git add %*
  git add %*
  exit /b %ERRORLEVEL%
)

set "repo="
for /f "delims=" %%R in ('git rev-parse --show-toplevel 2^>nul') do set "repo=%%R"
if not defined repo (
  echo Not a git repository>&2
  exit /b 2
)

set "tmp=%TEMP%\gs_add_files.txt"
del "%tmp%" 2>nul
set i=0
for /f "usebackq delims=" %%F in ('git diff --name-only') do (
  set /a i+=1
  echo !i!:%%F>>"%tmp%"
)
if %i%==0 (
  echo No changed files.
  del "%tmp%" 2>nul
  exit /b 0
)

for /f "delims=" %%L in ('type "%tmp%"') do echo %%L
set /p choice="Select file number to add (or empty to cancel): "
if "%choice%"=="" (
  del "%tmp%" 2>nul
  exit /b 0
)
for /f "usebackq tokens=1* delims=:" %%A in ('findstr /b "%choice%:" "%tmp%"') do set "file=%%B"
if not defined file (
  echo Invalid selection
  del "%tmp%" 2>nul
  exit /b 1
)
echo git add "!file!"
git add "!file!"
del "%tmp%" 2>nul
exit /b %ERRORLEVEL%