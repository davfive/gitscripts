# history-binary.ps1
param(
  [Parameter(Mandatory=$true, Position=0)]
  [string]$Path
)
$ErrorActionPreference = 'Stop'

Write-Host '===================================================================================='
Write-Host "$Path: binary hash history"
Write-Host '===================================================================================='
$hashes = (& git rev-list --all --objects -- $Path) -split "`n" | Where-Object { $_ -match [regex]::Escape($Path) } | ForEach-Object { ($_ -split '\s+')[0] }
foreach ($h in $hashes) { Write-Host "$Path:$h" }