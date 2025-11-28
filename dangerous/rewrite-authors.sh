#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# rewrite-authors.sh
#
# Purpose:
#   Rewrite git history replacing any author or committer whose name matches one
#   of the comma-separated names supplied via --from with a single target
#   identity (--to-name / --to-email).
#
# WARNING — Impact of history rewrite:
#   - Commit SHAs: all rewritten commits (and descendants) get NEW SHAs.
#   - Branch tips: branches will point to new commits; force-push required.
#   - Tags: lightweight and annotated tags move; signed tags/signatures break.
#   - GPG-signed commits: signatures become invalid.
#   - Open PRs/status checks: references to old SHAs won’t match; may need recreating.
#   - Collaborators: must reset/rebase to new history (or reclone).
#   - Scripts/docs: any hardcoded SHAs become stale.
#   - Submodules: if this repo is a submodule, parent repos must update pointers.
#
# Scope (optional revision/range limiting):
#   Positional arguments AFTER the options are passed directly to git (same
#   semantics as git rev-list). If none provided, all refs (--all) are rewritten.
#   Examples:
#     v1.0.0..              commits after tag v1.0.0 up to HEAD
#     v1.0.0..v1.2.0        commits between two tags
#     A..B                  commits after A up to B
#     main                  commits reachable from branch main
#     main ^feature         commits in main excluding those in feature
#
# Why filter-branch (vs filter-repo):
#   - Built-in, no external dependency.
#   - Predictable for modest repository sizes.
#
# Options:
#   --from "Name A,Name B,..."   (required) exact names to rewrite
#   --to-name NEW_NAME           (required) replacement author/committer name
#   --to-email NEW_EMAIL         (required) replacement email
#   --backup-dir PATH            (optional) override backup mirror directory
#
# Backup:
#   If --backup-dir not provided, a mirror is created at:
#       ../<repo>.rewrite-backup.<n>
#   where <n> is the first unused positive integer.
#
# Full history example:
#   bash scripts/rewrite-authors.sh \
#     --from "David May,David" \
#     --to-name davfive \
#     --to-email davfive@gmail.com
#
# Range-limited example (post v3.0.0-alpha only):
#   bash scripts/rewrite-authors.sh \
#     --from "David May" \
#     --to-name davfive \
#     --to-email davfive@gmail.com \
#     v3.0.0-alpha..
#
# Afterward (manual push):
#   git push --force-with-lease origin main --tags
# -----------------------------------------------------------------------------
set -euxo pipefail

# Globals
FROM_NAMES=""
TO_NAME=""
TO_EMAIL=""
BACKUP_DIR=""
FROM_LIST=""
RANGE_SPECS=()

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from)       FROM_NAMES="$2"; shift 2 ;;
      --to-name)    TO_NAME="$2"; shift 2 ;;
      --to-email)   TO_EMAIL="$2"; shift 2 ;;
      --backup-dir) BACKUP_DIR="$2"; shift 2 ;;
      --) shift; break ;;
      --*) echo "Unknown option: $1" >&2; exit 1 ;;
      *) break ;;
    esac
  done
  RANGE_SPECS=("$@")  # remaining positional args = range specs
  [[ -n "$FROM_NAMES" ]] || { echo "--from required" >&2; exit 1; }
  [[ -n "$TO_NAME"    ]] || { echo "--to-name required" >&2; exit 1; }
  [[ -n "$TO_EMAIL"   ]] || { echo "--to-email required" >&2; exit 1; }
}

build_from_list() {
  IFS=',' read -r -a arr <<< "$FROM_NAMES"
  local out=""
  for n in "${arr[@]}"; do
    local t
    t="$(echo "$n" | sed 's/^ *//;s/ *$//')"
    [[ -n "$t" ]] && out+="$t"$'\n'
  done
  [[ -n "$out" ]] || { echo "No valid names parsed from --from" >&2; exit 1; }
  FROM_LIST="$out"
}

allocate_backup_dir() {
  if [[ -n "$BACKUP_DIR" ]]; then
    return
  fi
  local top repo i=1 cand
  top="$(git rev-parse --show-toplevel)"
  repo="$(basename "$top")"
  while :; do
    cand="../${repo}.rewrite-backup.${i}"
    [[ -e "$cand" ]] || { BACKUP_DIR="$cand"; break; }
    i=$((i+1))
  done
}

mirror_backup() {
  echo "Backup directory: $BACKUP_DIR"
  git clone --mirror . "$BACKUP_DIR" || true
}

run_filter_branch() {
  local rev_args=()
  if [[ ${#RANGE_SPECS[@]} -gt 0 ]]; then
    rev_args=("${RANGE_SPECS[@]}")
    echo "Range specs: ${RANGE_SPECS[*]}"
  else
    rev_args=(--all)
    echo "No range specs (full history)."
  fi

  git filter-branch --env-filter "
while IFS= read -r SRC; do
  [ -z \"\$SRC\" ] && continue
  if [ \"\$GIT_AUTHOR_NAME\" = \"\$SRC\" ]; then
    GIT_AUTHOR_NAME='${TO_NAME}'
    GIT_AUTHOR_EMAIL='${TO_EMAIL}'
  fi
  if [ \"\$GIT_COMMITTER_NAME\" = \"\$SRC\" ]; then
    GIT_COMMITTER_NAME='${TO_NAME}'
    GIT_COMMITTER_EMAIL='${TO_EMAIL}'
  fi
done <<'NAMES'
${FROM_LIST}
NAMES
" --tag-name-filter cat -- "${rev_args[@]}"
}

cleanup_repository() {
  rm -rf .git/refs/original || true
  git for-each-ref --format='%(refname)' refs/original | xargs -r -n1 git update-ref -d || true
  git reflog expire --expire=now --all
  git gc --prune=now --aggressive
}

verify() {
  echo "Old author names remaining (author field):"
  git log --all --pretty='%an' | grep -Fx -f <(printf '%s' "$FROM_LIST" | sed '/^$/d') | wc -l || true
  echo "Old committer names remaining (committer field):"
  git log --all --pretty='%cn' | grep -Fx -f <(printf '%s' "$FROM_LIST" | sed '/^$/d') | wc -l || true
  echo "Sample rewritten commits:"
  git log --all --author="$TO_NAME" --pretty='%h %an <%ae>' | head || true
}

echo_push_instruction() {
  echo
  echo "To publish rewritten history run:"
  echo "git push --force-with-lease origin main --tags"
  echo
}

main() {
  parse_args "$@"
  build_from_list
  allocate_backup_dir
  mirror_backup
  run_filter_branch
  cleanup_repository
  verify
  echo_push_instruction
}

main "$@"
# -----------------------------------------------------------------------------
