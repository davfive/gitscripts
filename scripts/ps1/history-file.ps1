# history-file.ps1
param(
  [Parameter(Mandatory=$true, Position=0)]
  [string]$Path
)
$ErrorActionPreference = 'Stop'

$hashes = (& git rev-list --all --objects -- $Path) -split "`n" | Where-Object { $_ -match [regex]::Escape($Path) } | ForEach-Object { ($_ -split '\s+')[0] }
if (-not $hashes) { exit 0 }

foreach ($h in $hashes) {
  Write-Host '===================================================================================='
  Write-Host "cat-file $Path:$h"
  Write-Host '===================================================================================='
  git cat-file -p $h
}