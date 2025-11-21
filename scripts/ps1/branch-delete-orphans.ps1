# branch-delete-orphans.ps1
$ErrorActionPreference = 'Stop'

Write-Host "Fetching latest git references ..."
git fetch -p

Write-Host ""
Write-Host "Local branches with deleted remote:"
$branches = (& git branch -vv) -split "`n" | Where-Object { $_ -and ($_ -notmatch '^\*') -and ($_ -match ': gone]') } | ForEach-Object { ($_ -split '\s+')[0] }

if (-not $branches) {
  Write-Host "No orphaned local branches found."
  exit 0
}

foreach ($branch in $branches) {
  Write-Host ""
  Write-Host "Delete local orphaned branch $branch?"
  $yn = Read-Host "Delete? (y/N)"
  if ($yn -match '^[Yy]') {
    git branch -D $branch
  }
}