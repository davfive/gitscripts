# checkout-select.ps1
$ErrorActionPreference = 'Stop'

Write-Host 'Revert file (git checkout -- <file>)'
$lines = (& git status -s) -split "`n"
$files = foreach ($l in $lines) {
  $trim = $l.Trim()
  if ($trim -and ($trim -notmatch '^[A-Z]')) {
    ($trim -split '\s+')[1]
  }
}
$files = $files | Where-Object { $_ } 
if (-not $files) { Write-Host "No candidate files to revert."; exit 0 }

for ($i=0; $i -lt $files.Count; $i++) { Write-Host ("[{0}] {1}" -f ($i+1), $files[$i]) }
$sel = Read-Host "Select number"
if (-not ($sel -as [int])) { Write-Host "Invalid"; exit 1 }
$idx = [int]$sel - 1
if ($idx -lt 0 -or $idx -ge $files.Count) { Write-Host "Out of range"; exit 1 }
$file = $files[$idx]
Write-Host "git checkout -- $file" -ForegroundColor Yellow
git checkout -- $file
exit $LASTEXITCODE