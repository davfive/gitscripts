# branch-select.ps1
$ErrorActionPreference = 'Stop'

$current = (& git branch 2>$null) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -like '* *' } # fallback
$current = (& git branch 2>$null) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\*' } | ForEach-Object { $_ -replace '^\* ','' } | Select-Object -First 1
$localBranches = (& git branch 2>$null) -split "`n" | ForEach-Object { ($_ -replace '^\* ','').Trim() } | Sort-Object -Unique
$listAll = '**List-All**'

Write-Host "Local branches:"
$opts = $localBranches + $listAll
for ($i=0; $i -lt $opts.Count; $i++) { Write-Host ("[{0}] {1}" -f ($i+1), $opts[$i]) }

$sel = Read-Host "Select number"
if (-not ($sel -as [int])) { Write-Host "Invalid"; exit 1 }
$sel = [int]$sel - 1
if ($sel -lt 0 -or $sel -ge $opts.Count) { Write-Host "Out of range"; exit 1 }

$choice = $opts[$sel]
if ($choice -eq $listAll) {
  Write-Host 'All Branches: (fetching first)'
  git fetch 2>$null | Out-Null
  $allBranches = (& git branch -a) -replace '^\* ',''
  $allBranches = $allBranches -replace 'remotes/.*/','' | Sort-Object -Unique
  $candidates = $allBranches | Where-Object { $_ -ne $current }
  for ($i=0; $i -lt $candidates.Count; $i++) { Write-Host ("[{0}] {1}" -f ($i+1), $candidates[$i]) }
  $sel2 = Read-Host "Select number"
  if (-not ($sel2 -as [int])) { Write-Host "Invalid"; exit 1 }
  $sel2 = [int]$sel2 - 1
  if ($sel2 -lt 0 -or $sel2 -ge $candidates.Count) { Write-Host "Out of range"; exit 1 }
  $branch = $candidates[$sel2]
  Write-Host "git checkout $branch" -ForegroundColor Yellow
  git checkout $branch
  exit $LASTEXITCODE
} else {
  Write-Host "git checkout $choice" -ForegroundColor Yellow
  git checkout $choice
  exit $LASTEXITCODE
}