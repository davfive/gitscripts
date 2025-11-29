#!/usr/bin/env bash
# filepath: /Users/davidmay/davfive/scripts/extract-main-branch.sh
# -----------------------------------------------------------------------------
# extract-main-branch.sh
#
# Purpose:
#   Create a fresh repository containing only the main branch history,
#   preserving all commits, authors, committers, and timestamps.
#
# Usage:
#   bash scripts/extract-main-branch.sh <source-repo-path> <target-repo-path>
#
# Example:
#   bash scripts/extract-main-branch.sh ~/davfive/gitspaces/rewrite-9 ~/davfive/gitspaces/main-only
#
# What it does:
#   1. Clone source repo
#   2. Remove all refs except main branch
#   3. Garbage collect unreachable objects
#   4. Push to new remote repository
#
# Afterward:
#   - Target repo contains only main branch history
#   - All commits retain original SHAs, authors, dates
#   - Old feature branches and their commits are gone
# -----------------------------------------------------------------------------
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  extract-main-branch.sh <source-repo-path> <target-repo-path>

Arguments:
  source-repo-path    Path to existing git repository
  target-repo-path    Path where new repo will be created

Example:
  bash scripts/extract-main-branch.sh ~/davfive/gitspaces/rewrite-9 ~/davfive/gitspaces/main-only
EOF
  exit 2
}

[[ $# -eq 2 ]] || usage
SOURCE_REPO="$1"
TARGET_REPO="$2"

[[ -d "$SOURCE_REPO/.git" ]] || { echo "Error: $SOURCE_REPO is not a git repository" >&2; exit 1; }
[[ -e "$TARGET_REPO" ]] && { echo "Error: $TARGET_REPO already exists" >&2; exit 1; }

echo "=========================================="
echo "Extracting main branch"
echo "=========================================="
echo "Source: $SOURCE_REPO"
echo "Target: $TARGET_REPO"
echo

# Because: create fresh clone with full history
echo "Step 1: Cloning source repository..."
git clone "$SOURCE_REPO" "$TARGET_REPO"
cd "$TARGET_REPO"

# Because: verify main branch exists
if ! git show-ref --verify --quiet refs/heads/main; then
  echo "Error: main branch does not exist in source repository" >&2
  exit 1
fi

echo "Step 2: Removing all branches except main..."
# Because: delete all local branches except main (macOS-compatible)
BRANCHES_TO_DELETE=$(git for-each-ref --format='%(refname:short)' refs/heads | grep -v '^main$' || true)
if [[ -n "$BRANCHES_TO_DELETE" ]]; then
  echo "$BRANCHES_TO_DELETE" | while read branch; do
    echo "  Deleting branch: $branch"
    git branch -D "$branch"
  done
else
  echo "  No branches to delete (only main exists)"
fi

# Because: remove all remote-tracking branches (macOS-compatible, exclude HEAD and main)
REMOTE_BRANCHES=$(git for-each-ref --format='%(refname:short)' refs/remotes/origin | grep -v -E '^(origin/HEAD|origin/main|origin)$' || true)
if [[ -n "$REMOTE_BRANCHES" ]]; then
  echo "$REMOTE_BRANCHES" | while read remote_branch; do
    echo "  Deleting remote-tracking branch: $remote_branch"
    git branch -rd "$remote_branch"
  done
else
  echo "  No remote-tracking branches to delete"
fi

# Because: remove origin/main remote-tracking branch (we keep local main only)
if git show-ref --verify --quiet refs/remotes/origin/main; then
  echo "  Deleting remote-tracking branch: origin/main"
  git branch -rd origin/main
fi

# Because: remove all tags (macOS-compatible)
TAGS=$(git tag || true)
if [[ -n "$TAGS" ]]; then
  echo "$TAGS" | while read tag; do
    echo "  Deleting tag: $tag"
    git tag -d "$tag"
  done
else
  echo "  No tags to delete"
fi

echo "Step 3: Garbage collecting unreachable objects..."
# Because: remove refs/original if filter-branch was used
rm -rf .git/refs/original

# Because: expire reflog immediately
git reflog expire --expire=now --all

# Because: count objects before GC
OBJECTS_BEFORE=$(git count-objects -v | grep '^count:' | awk '{print $2}')
SIZE_BEFORE=$(git count-objects -v | grep '^size-pack:' | awk '{print $2}')
echo "Objects before GC: $OBJECTS_BEFORE (pack size: ${SIZE_BEFORE}K)"

# Because: aggressive garbage collection to remove unreachable commits
git gc --prune=now --aggressive

# Because: count objects after GC
OBJECTS_AFTER=$(git count-objects -v | grep '^count:' | awk '{print $2}')
SIZE_AFTER=$(git count-objects -v | grep '^size-pack:' | awk '{print $2}')
REMOVED=$((OBJECTS_BEFORE - OBJECTS_AFTER))
echo "Objects after GC: $OBJECTS_AFTER (pack size: ${SIZE_AFTER}K, removed: $REMOVED objects)"

echo "Step 4: Verifying repository state..."
echo "Branches:"
git branch -a
echo
echo "Commit count on main:"
git rev-list --count main
echo
echo "Latest commits:"
git log main -5 --oneline --pretty='%h %an <%ae> | %s'
echo

# Because: verify no unreachable commits remain
UNREACHABLE=$(git fsck --unreachable --no-reflogs 2>/dev/null | grep -c '^unreachable commit' || true)
if [[ $UNREACHABLE -gt 0 ]]; then
  echo "⚠️  WARNING: $UNREACHABLE unreachable commits still present"
  echo "    Run 'git gc --prune=now --aggressive' again if needed"
else
  echo "✓ No unreachable commits found"
fi

echo
echo "=========================================="
echo "Extraction complete!"
echo "=========================================="
echo
echo "Repository location: $TARGET_REPO"
echo
echo "To push to a new GitHub repository:"
echo
cat <<PUSHSCRIPT
set -euxo pipefail

# Because: create new empty repository on GitHub first
# Go to: https://github.com/new
# Repository name: gitspaces (or gitspaces-clean)
# Do NOT initialize with README, .gitignore, or license

# Because: navigate to target repository
cd $TARGET_REPO

# Because: update origin remote to point to new repository
git remote set-url origin git@github.com:davfive/gitspaces.git

# Because: push main branch only (no feature branches)
git push -u origin main

# Afterward: verify remote has only main branch
git ls-remote origin

# Because: confirm no unreachable objects on remote
git log --oneline --graph --all

PUSHSCRIPT

echo