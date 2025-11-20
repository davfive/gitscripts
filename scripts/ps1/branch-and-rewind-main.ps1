<#
gitscripts/ps1/branch-and-rewind-main.ps1
PowerShell variant.
Usage: pwsh .\branch-and-rewind-main.ps1 <new-branch-name>
#>
param(
  [Parameter(Mandatory=$true, Position=0)]
  [string]$Branch
)

function Fail([int]$code, [string]$msg) {
  Write-Error $msg
  exit $code
}

$null = & git rev-parse --git-dir 2>$null
if ($LASTEXITCODE -ne 0) { Fail 1 "Not a git repository" }

$currentBranch = (& git symbolic-ref --short HEAD 2>$null).Trim()
if ($currentBranch -ne 'main') { Fail 1 "Please run this from branch 'main' (current: $currentBranch)" }

if (& git show-ref --verify --quiet "refs/heads/$Branch"; $LASTEXITCODE -eq 0) {
  Fail 1 "Branch '$Branch' already exists. Choose a different name or delete the existing branch."
}

$stashed = $false
& git update-index -q --refresh
if ((& git diff-index --quiet HEAD --; $LASTEXITCODE) -ne 0 -or (& git ls-files --others --exclude-standard) -ne $null) {
  $stashMsg = "auto-branch-$Branch-{0:yyyyMMddTHHmmssZ}" -f (Get-Date).ToUniversalTime()
  Write-Host "Stashing changes: $stashMsg"
  & git stash push --include-untracked -m $stashMsg
  $stashed = $true
}

& git branch $Branch
if ($LASTEXITCODE -ne 0) { Fail 1 "Failed to create branch $Branch" }
Write-Host "Created branch '$Branch' at current HEAD."

$hasOriginMain = (& git show-ref --verify --quiet refs/remotes/origin/main; $LASTEXITCODE) -eq 0
if ($hasOriginMain) {
  & git reset --hard refs/remotes/origin/main
  if ($LASTEXITCODE -ne 0) { Fail 1 "git reset failed" }
  Write-Host "Reset 'main' to refs/remotes/origin/main (last fetched state)."
} else {
  Write-Warning "refs/remotes/origin/main not found. Run 'git fetch origin' if you want latest remote."
  if ($stashed) {
    & git switch $Branch
    Write-Host "Restoring stashed changes onto '$Branch'..."
    & git stash pop --index
    if ($LASTEXITCODE -ne 0) { Fail 1 "git stash pop had conflicts. Resolve manually." }
  }
  exit 1
}

& git switch $Branch
if ($LASTEXITCODE -ne 0) { Fail 1 "Failed to switch to $Branch" }
if ($stashed) {
  Write-Host "Restoring stashed changes onto '$Branch'..."
  & git stash pop --index
  if ($LASTEXITCODE -ne 0) { Fail 1 "git stash pop had conflicts. Resolve manually." }
}

Write-Host "Done: on '$Branch' with working tree restored. main matches refs/remotes/origin/main."