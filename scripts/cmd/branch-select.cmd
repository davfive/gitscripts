@echo off
rem branch-select.cmd
setlocal EnableDelayedExpansion
for /f "delims=" %%R in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set "cur=%%R"

rem list local branches
set "tmp=%TEMP%\branches.txt"
del "%tmp%" 2>nul
for /f "delims=" %%B in ('git branch') do (
  set "ln=%%B"
  setlocal enabledelayedexpansion
  set "ln=!ln:*  =!"
  endlocal & >>"%tmp%" echo %%B
)

rem add sentinel
>>"%tmp%" echo **List-All**

set i=0
for /f "usebackq delims=" %%L in ("%tmp%") do (
  set /a i+=1
  echo [!i!] %%L
)

set /p sel="Select number: "
if "%sel%"=="" ( del "%tmp%" 2>nul & exit /b 1 )
for /f "usebackq tokens=1* delims=:" %%A in ('findstr /b "%sel%:" "%tmp%"') do set "choice=%%B"
if "%choice%"=="**List-All**" (
  echo All Branches: (fetching first)
  git fetch 2>nul
  del "%tmp%" 2>nul
  for /f "delims=" %%B in ('git branch -a ^| sed "s/^\* //"' ) do echo %%B >> "%tmp%" 2>nul
  rem Note: sed might not exist on Windows; fallback to 'git branch -a' output raw.
  for /f "usebackq delims=" %%L in ("%tmp%") do (
    set /a j+=1
    echo [!j!] %%L
  )
  set /p sel2="Select number: "
  for /f "usebackq tokens=1* delims=:" %%A in ('findstr /b "%sel2%:" "%tmp%"') do set "branch=%%B"
  echo git checkout "%branch%"
  git checkout "%branch%"
  del "%tmp%" 2>nul
  exit /b %ERRORLEVEL%
) else (
  echo git checkout "%choice%"
  git checkout "%choice%"
  del "%tmp%" 2>nul
  exit /b %ERRORLEVEL%
)