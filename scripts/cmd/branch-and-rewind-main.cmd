@echo off
rem gitscripts\cmd\branch-and-rewind-main.cmd
rem Usage: branch-and-rewind-main.cmd <new-branch-name>
if "%~1"=="" (
  echo Usage: %~nx0 ^<new-branch-name^>
  exit /b 2
)
set "BRANCH=%~1"

for /f "delims=" %%R in ('git rev-parse --git-dir 2^>nul') do set "GITDIR=%%R"
if not defined GITDIR (
  echo Not a git repository>&2
  exit /b 1
)

for /f "delims=" %%R in ('git symbolic-ref --short HEAD 2^>nul') do set "CUR=%%R"
if not defined CUR set "CUR=<detached>"
if /i not "%CUR%"=="main" (
  echo Please run this from branch 'main' (current: %CUR%)>&2
  exit /b 1
)

git check-ref-format --branch "refs/heads/%BRANCH%" >nul 2>&1
if not %ERRORLEVEL%==0 (
  echo Invalid branch name: '%BRANCH%'>&2
  exit /b 1
)

git show-ref --verify --quiet "refs/heads/%BRANCH%"
if %ERRORLEVEL%==0 (
  echo Branch '%BRANCH%' already exists. Choose a different name or delete the existing branch.>&2
  exit /b 1
)

set "STASHED=0"
git diff-index --quiet HEAD -- 2>nul
if not %ERRORLEVEL%==0 (
  git stash push --include-untracked -m "auto-branch-%BRANCH%"
  if %ERRORLEVEL%==0 set "STASHED=1"
)

git branch "%BRANCH%"
if not %ERRORLEVEL%==0 (
  echo Failed to create branch '%BRANCH%'>&2
  exit /b 1
)

git show-ref --verify --quiet refs/remotes/origin/main
if %ERRORLEVEL%==0 (
  git reset --hard refs/remotes/origin/main
  if not %ERRORLEVEL%==0 (
    echo git reset failed>&2
    exit /b 1
  )
) else (
  echo refs/remotes/origin/main not found. Run 'git fetch origin' if you want latest remote.>&2
  if "%STASHED%"=="1" (
    git switch "%BRANCH%"
    git stash pop --index
    if not %ERRORLEVEL%==0 (
      echo git stash pop had conflicts. Resolve them manually.>&2
      exit /b 1
    )
  )
  exit /b 1
)

git switch "%BRANCH%"
if not %ERRORLEVEL%==0 (
  echo Failed to switch to '%BRANCH%'>&2
  exit /b 1
)

if "%STASHED%"=="1" (
  git stash pop --index
  if not %ERRORLEVEL%==0 (
    echo git stash pop had conflicts. Resolve them manually.>&2
    exit /b 1
  )
)

echo Done: on '%BRANCH%' with working tree restored. main matches refs/remotes/origin/main.