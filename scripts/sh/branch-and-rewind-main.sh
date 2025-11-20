#!/usr/bin/env bash
set -euo pipefail

# Usage: ./branch-and-rewind-main.sh <new-branch-name>

if [[ ${#} -lt 1 || -z "${1:-}" ]]; then
  echo "Usage: $0 <new-branch-name>" >&2
  exit 1
fi
BRANCH="$1"

git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repository" >&2; exit 1; }
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "<detached>")
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "Please run this from branch 'main' (current: $CURRENT_BRANCH)" >&2
  exit 1
fi

if ! git check-ref-format --branch "refs/heads/$BRANCH" >/dev/null 2>&1; then
  echo "Invalid branch name: '$BRANCH'" >&2
  exit 1
fi
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "Branch '$BRANCH' already exists. Choose a different name or delete the existing branch." >&2
  exit 1
fi

STASHED=0
if ! git diff-index --quiet HEAD -- || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  STASH_MSG="auto-branch-$BRANCH-$(date -u +%Y%m%dT%H%M%SZ)"
  echo "Stashing changes: $STASH_MSG"
  git stash push --include-untracked -m "$STASH_MSG"
  STASHED=1
fi

git branch "$BRANCH"
echo "Created branch '$BRANCH' at current HEAD."

if git show-ref --verify --quiet refs/remotes/origin/main; then
  git reset --hard refs/remotes/origin/main
  echo "Reset 'main' to refs/remotes/origin/main (last fetched state)."
else
  echo "refs/remotes/origin/main not found. Run 'git fetch origin' if you want latest remote." >&2
  if [[ $STASHED -eq 1 ]]; then
    git switch "$BRANCH"
    echo "Restoring stashed changes onto '$BRANCH'..."
    if ! git stash pop --index; then
      echo "git stash pop had conflicts. Resolve them manually." >&2
      exit 1
    fi
  fi
  exit 1
fi

git switch "$BRANCH"
if [[ $STASHED -eq 1 ]]; then
  echo "Restoring stashed changes onto '$BRANCH'..."
  if ! git stash pop --index; then
    echo "git stash pop failed (possible conflicts). Resolve them on the branch and inspect 'git stash list'." >&2
    exit 1
  fi
fi

echo "Done: on '$BRANCH' with working tree restored. main matches refs/remotes/origin/main."