# branch-parent.ps1
$ErrorActionPreference = 'Stop'

$current = (& git rev-parse --abbrev-ref HEAD).Trim()
$line = (& git show-branch -a) -split "`n" | Where-Object { $_ -match '\*' -and ($_ -notmatch [regex]::Escape($current)) } | Select-Object -First 1
if (-not $line) { exit 0 }
if ($line -match '\[(.*?)\]') {
  $parent = $Matches[1] -replace '[\^~].*',''
  Write-Host $parent
}