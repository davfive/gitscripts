<# Unified PowerShell runner — updated to new layout #>
param(
  [Parameter(Position=0)][string]$ScriptName = "",
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$RemainingArgs
)

$ErrorActionPreference = 'Stop'

function Show-Help {
  $repoRoot = (& git rev-parse --show-toplevel 2>$null).Trim()
  if (-not $repoRoot) { Write-Error "Not a git repository"; exit 2 }

  Write-Host "Usage: git gs <script-name> [args...]"
  Write-Host ""
  Write-Host "Available commands:"
  $patterns = @(
    (Join-Path $repoRoot "gitscripts\scripts\ps1\*.ps1"),
    (Join-Path $repoRoot "gitscripts\scripts\sh\*.sh"),
    (Join-Path $repoRoot "gitscripts\scripts\cmd\*.cmd"),
    (Join-Path $repoRoot "gitscripts\scripts\cmd\*.bat"),
    (Join-Path $repoRoot "gitscripts\*.*"),
    (Join-Path $repoRoot "gitscripts\user-scripts-untracked\*.*")
  )

  $found = @()
  foreach ($pat in $patterns) {
    foreach ($f in Get-ChildItem -Path $pat -ErrorAction SilentlyContinue) {
      if ($f.PSIsContainer) { continue }
      $name = [IO.Path]::GetFileNameWithoutExtension($f.Name)
      $ext  = $f.Extension.TrimStart('.').ToLowerInvariant()
      $found += [PSCustomObject]@{Name=$name; Ext=$ext}
    }
  }

  $found | Sort-Object Name -Unique | ForEach-Object {
    $label = switch ($_.Ext) {
      'ps1' { '(ps1)' }
      'sh'  { '(sh)' }
      'cmd' { '(cmd)' }
      'bat' { '(cmd)' }
      default { '(other)' }
    }
    Write-Host ("  {0,-25} {1}" -f $_.Name, $label)
  }
  exit 0
}

if ([string]::IsNullOrEmpty($ScriptName) -or $ScriptName -in @('--help','-h','help','list')) {
  Show-Help
}

$repoRoot = (& git rev-parse --show-toplevel 2>$null).Trim()
if (-not $repoRoot) { Write-Error "Not a git repository"; exit 2 }

$candidates = @(
  Join-Path $repoRoot "gitscripts\scripts\ps1\$ScriptName.ps1",
  Join-Path $repoRoot "gitscripts\scripts\sh\$ScriptName.sh",
  Join-Path $repoRoot "gitscripts\scripts\cmd\$ScriptName.cmd",
  Join-Path $repoRoot "gitscripts\scripts\cmd\$ScriptName.bat",
  Join-Path $repoRoot "gitscripts\$ScriptName",
  Join-Path $repoRoot "gitscripts\$ScriptName.ps1",
  Join-Path $repoRoot "gitscripts\$ScriptName.sh",
  Join-Path $repoRoot "gitscripts\$ScriptName.cmd",
  Join-Path $repoRoot "gitscripts\$ScriptName.bat",
  Join-Path $repoRoot "gitscripts\user-scripts-untracked\$ScriptName",
  Join-Path $repoRoot "gitscripts\user-scripts-untracked\$ScriptName.ps1",
  Join-Path $repoRoot "gitscripts\user-scripts-untracked\$ScriptName.sh",
  Join-Path $repoRoot "gitscripts\user-scripts-untracked\$ScriptName.cmd",
  Join-Path $repoRoot "gitscripts\user-scripts-untracked\$ScriptName.bat"
)

$found = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $found) {
  Write-Error "Script not found: $ScriptName"
  Write-Host "Run 'git gs --help' to list commands."
  exit 127
}

$ext = [IO.Path]::GetExtension($found).ToLowerInvariant()
switch ($ext) {
  '.ps1' { & $found @RemainingArgs; exit $LASTEXITCODE }
  '.cmd'  { cmd.exe /c "`"$found`" $($RemainingArgs -join ' ')"; exit $LASTEXITCODE }
  '.bat'  { cmd.exe /c "`"$found`" $($RemainingArgs -join ' ')"; exit $LASTEXITCODE }
  '.sh'   {
    if (Get-Command bash -ErrorAction SilentlyContinue) { & bash $found @RemainingArgs; exit $LASTEXITCODE }
    else { Write-Error "bash not available to run $found"; exit 126 }
  }
  default {
    try { & $found @RemainingArgs; exit $LASTEXITCODE } catch { Write-Error "No suitable interpreter found for $found"; exit 126 }
  }
}