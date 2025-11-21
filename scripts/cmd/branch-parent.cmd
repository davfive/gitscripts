@echo off
rem branch-parent.cmd
setlocal EnableDelayedExpansion
for /f "delims=" %%R in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set "cur=%%R"
for /f "delims=" %%L in ('git show-branch -a ^| findstr "\*" ^| findstr /v "%cur%"') do (
  set "line=%%L"
  rem extract content inside [ ... ]
  for /f "tokens=1* delims=[" %%A in ("!line!") do (
    for /f "tokens=1 delims=]" %%X in ("%%B") do (
      set "parent=%%X"
      rem strip ^ or ~ suffix
      for /f "delims=^~" %%P in ("!parent!") do set "parent=%%P"
      echo !parent!
      goto :done
    )
  )
)
:done