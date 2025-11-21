@echo off
rem diff-select.cmd
setlocal EnableDelayedExpansion
set "from=%~1"
set "tmp=%TEMP%\diff_files.txt"
del "%tmp%" 2>nul
set i=0
for /f "usebackq delims=" %%F in ('git diff --name-only %from%') do (
  set /a i+=1
  echo [!i!] %%F
  echo !i!:%%F>>"%tmp%"
)
if %i%==0 (
  echo No files to diff.
  exit /b 0
)
set /p sel="Select number: "
for /f "usebackq tokens=1* delims=:" %%A in ('findstr /b "%sel%:" "%tmp%"') do set "file=%%B"
if not defined file ( echo Invalid selection & del "%tmp%" 2>nul & exit /b 1 )
echo git diff %from% -- "%file%"
git diff %from% -- "%file%"
del "%tmp%" 2>nul
exit /b %ERRORLEVEL%