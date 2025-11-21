# branch-create.ps1
param(
  [Parameter(Mandatory=$true, Position=0)]
  [string]$Name
)
$ErrorActionPreference = 'Stop'

$allBranches = (& git branch -a) -replace '^\* ',''
$allBranches = $allBranches -replace 'remotes/.*/','' | Sort-Object -Unique

if ($allBranches -contains $Name) {
  Write-Host "Branch already exists"
  exit 1
}

Write-Host "Creating new branch: '$Name'" -ForegroundColor Yellow
git checkout -b $Name
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git push --set-upstream origin $Name
exit $LASTEXITCODE