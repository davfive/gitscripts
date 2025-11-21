@echo off
rem checkout-select.cmd
setlocal EnableDelayedExpansion
echo Revert file (git checkout -- <file>)
set "tmp=%TEMP%\checkout_files.txt"
del "%tmp%" 2>nul
for /f "usebackq delims=" %%F in ('git status -s') do (
  rem skip lines that start with uppercase letter in the output (approximate)
  echo %%F>>"%tmp%"
)
rem now extract second token per line
set i=0
for /f "usebackq tokens=2 delims= " %%A in ("%tmp%") do (
  set /a i+=1
  echo [!i!] %%A
  echo !i!:%%A>>"%tmp%.nums"
)
if %i%==0 (
  echo No candidate files to revert.
  del "%tmp%" 2>nul
  del "%tmp%.nums" 2>nul
  exit /b 0
)
set /p choice="Select number: "
for /f "usebackq tokens=1* delims=:" %%A in ('findstr /b "%choice%:" "%tmp%.nums"') do set "file=%%B"
if not defined file ( echo Invalid selection & del "%tmp%" 2>nul & del "%tmp%.nums" 2>nul & exit /b 1 )
echo git checkout -- "%file%"
git checkout -- "%file%"
del "%tmp%" 2>nul
del "%tmp%.nums" 2>nul
exit /b %ERRORLEVEL%