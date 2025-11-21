@echo off
rem branch-create.cmd
setlocal
if "%~1"=="" (
  echo usage: branch-create.cmd ^<branch-name^>
  exit /b 1
)
set "name=%~1"
set "exists=0"
for /f "delims=" %%B in ('git branch -a') do (
  set "ln=%%B"
  setlocal enabledelayedexpansion
  set "ln2=!ln:*remotes/=!"
  endlocal & set "ln2=%ln2%"
  for /f "delims=" %%X in ('echo %ln2%') do (
    echo %ln2% | findstr /x /c:"%name%" >nul && set "exists=1"
  )
)
if "%exists%"=="1" (
  echo Branch already exists
  exit /b 1
)
echo Creating new branch: "%name%"
echo git checkout -b "%name%"
git checkout -b "%name%"
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
git push --set-upstream origin "%name%"
exit /b %ERRORLEVEL%