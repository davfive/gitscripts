# add-select.ps1
param(
  [Parameter(ValueFromRemainingArguments=$true)]
  [string[]] $ArgsRemaining
)
$ErrorActionPreference = 'Stop'

if ($ArgsRemaining.Count -gt 0) {
  Write-Host "git add $($ArgsRemaining -join ' ')" -ForegroundColor Yellow
  git add @ArgsRemaining
  exit $LASTEXITCODE
}

$files = (& git diff --name-only) -split "`n" | Where-Object { $_ -ne '' }
if (-not $files) {
  Write-Host "No changed files."
  exit 0
}

for ($i=0; $i -lt $files.Count; $i++) {
  Write-Host ("[{0}] {1}" -f ($i+1), $files[$i])
}

$choice = Read-Host "Select file number to add (or empty to cancel)"
if ([string]::IsNullOrWhiteSpace($choice)) { exit 0 }
if (-not ($choice -as [int])) { Write-Host "Invalid choice"; exit 1 }
$idx = [int]$choice - 1
if ($idx -lt 0 -or $idx -ge $files.Count) { Write-Host "Out of range"; exit 1 }

$file = $files[$idx]
Write-Host "git add $file" -ForegroundColor Yellow
git add -- $file
exit $LASTEXITCODE