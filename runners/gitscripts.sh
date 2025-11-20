#!/usr/bin/env sh
# POSIX unified runner — updated for new layout (scripts/ and user-scripts-untracked)
set -eu

show_help_and_exit() {
  repo_root="$1"
  cat <<EOF
Usage: git gs <script> [args...]

Available commands (scanned under gitscripts/scripts, tracked top-level files, and gitscripts/user-scripts-untracked):
EOF

  {
    for f in "$repo_root/gitscripts/scripts/sh"/*.sh; do
      [ -e "$f" ] || continue
      printf "%s\t(sh)\n" "$(basename "${f%.sh}")"
    done 2>/dev/null

    for f in "$repo_root/gitscripts/scripts/ps1"/*.ps1; do
      [ -e "$f" ] || continue
      printf "%s\t(ps1)\n" "$(basename "${f%.ps1}")"
    done 2>/dev/null

    for f in "$repo_root/gitscripts/scripts/cmd"/*.cmd "$repo_root/gitscripts/scripts/cmd"/*.bat; do
      [ -e "$f" ] || continue
      base="$(basename "$f")"
      name="${base%.*}"
      printf "%s\t(cmd)\n" "$name"
    done 2>/dev/null

    for f in "$repo_root/gitscripts"/*; do
      [ -e "$f" ] || continue
      [ -d "$f" ] && continue
      base="$(basename "$f")"
      case "$base" in
        runners|gitconfig|scripts|user-scripts-untracked) continue ;;
      esac
      name="${base%.*}"
      printf "%s\t(tracked)\n" "$name"
    done 2>/dev/null

    for f in "$repo_root/gitscripts/user-scripts-untracked"/*; do
      [ -e "$f" ] || continue
      base="$(basename "$f")"
      name="${base%.*}"
      printf "%s\t(untracked)\n" "$name"
    done 2>/dev/null
  } | awk '!seen[$1]++ { printf "  %-28s %s\n", $1, $2 }'

  exit 0
}

if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ "$1" = "help" ]; then
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Not a git repository" >&2
    exit 2
  }
  show_help_and_exit "$repo_root"
fi

script_name=$1
shift || true

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "Not a git repository (git rev-parse failed)" >&2
  exit 2
}

# search order: tracked scripts/ (sh, ps1, cmd), tracked top-level, user-scripts-untracked
candidates="
$repo_root/gitscripts/scripts/sh/${script_name}.sh
$repo_root/gitscripts/scripts/ps1/${script_name}.ps1
$repo_root/gitscripts/scripts/cmd/${script_name}.cmd
$repo_root/gitscripts/scripts/cmd/${script_name}.bat
$repo_root/gitscripts/${script_name}
$repo_root/gitscripts/${script_name}.sh
$repo_root/gitscripts/${script_name}.ps1
$repo_root/gitscripts/${script_name}.cmd
$repo_root/gitscripts/${script_name}.bat
$repo_root/gitscripts/user-scripts-untracked/${script_name}
$repo_root/gitscripts/user-scripts-untracked/${script_name}.sh
$repo_root/gitscripts/user-scripts-untracked/${script_name}.ps1
$repo_root/gitscripts/user-scripts-untracked/${script_name}.cmd
$repo_root/gitscripts/user-scripts-untracked/${script_name}.bat
"

found=""
for p in $candidates; do
  if [ -e "$p" ]; then
    found="$p"
    break
  fi
done

if [ -z "$found" ]; then
  echo "Script not found: $script_name" >&2
  echo "Run 'git gs --help' to list available commands." >&2
  exit 127
fi

if [ -x "$found" ]; then
  exec "$found" "$@"
fi

case "$found" in
  *.ps1)
    if command -v pwsh >/dev/null 2>&1; then
      exec pwsh -NoProfile -ExecutionPolicy Bypass -File "$found" -- "$@"
    elif command -v powershell >/dev/null 2>&1; then
      exec powershell -NoProfile -ExecutionPolicy Bypass -File "$found" -- "$@"
    else
      echo "PowerShell not available to run $found" >&2
      exit 126
    fi
    ;;
  *.cmd|*.bat)
    if command -v cmd >/dev/null 2>&1; then
      cmd /c "\"$found\" %*"
      exit $?
    else
      echo "cmd.exe not available to run $found" >&2
      exit 126
    fi
    ;;
  *.sh)
    if command -v bash >/dev/null 2>&1; then
      exec bash "$found" "$@"
    elif command -v sh >/dev/null 2>&1; then
      exec sh "$found" "$@"
    else
      echo "No shell available to run $found" >&2
      exit 126
    fi
    ;;
  *)
    if command -v sh >/dev/null 2>&1; then
      exec sh "$found" "$@"
    else
      echo "No suitable interpreter found for $found" >&2
      exit 126
    fi
    ;;
esac