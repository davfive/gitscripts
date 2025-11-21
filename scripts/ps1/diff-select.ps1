# diff-select.ps1
param(
  [Parameter(ValueFromRemainingArguments=$true)]
  [string[]] $Args
)
$ErrorActionPreference = 'Stop'

$from = if ($Args.Count -ge 1) { $Args[0] } else { '' }
$files = (& git diff --name-only $from) -split "`n" | Where-Object { $_ -ne '' }
if (-not $files) { Write-Host "No files to diff."; exit 0 }

for ($i=0; $i -lt $files.Count; $i++) { Write-Host ("[{0}] {1}" -f ($i+1), $files[$i]) }
$sel = Read-Host "Select number"
if (-not ($sel -as [int])) { Write-Host "Invalid"; exit 1 }
$idx = [int]$sel - 1
if ($idx -lt 0 -or $idx -ge $files.Count) { Write-Host "Out of range"; exit 1 }
$file = $files[$idx]

Write-Host "git diff $from -- $file" -ForegroundColor Yellow
git diff $from -- $file
exit $LASTEXITCODE