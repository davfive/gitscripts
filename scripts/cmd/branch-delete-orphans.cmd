@echo off
rem branch-delete-orphans.cmd
setlocal EnableDelayedExpansion
echo Fetching latest git references ...
git fetch -p
echo.
echo Local branches with deleted remote:
set "found="
for /f "delims=" %%B in ('git branch -vv ^| findstr /v "^\*" ^| findstr ": gone]"') do (
  for /f "tokens=1" %%b in ("%%B") do (
    set "found=!found! %%b"
  )
)
if "%found%"=="" (
  echo No orphaned local branches found.
  exit /b 0
)

for %%b in (%found%) do (
  echo.
  echo Delete local orphaned branch %%b?
  set /p yn="Delete? (y/N): "
  if /i "!yn!"=="y" (
    git branch -D "%%b"
  )
)