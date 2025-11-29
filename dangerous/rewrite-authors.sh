#!/usr/bin/env bash
# filepath: /Users/davidmay/davfive/scripts/rewrite-authors.sh
# -----------------------------------------------------------------------------
# rewrite-authors.sh
#
# Purpose:
#   Rewrite git history replacing any author or committer whose identity matches
#   one of the selectors supplied via --from with a single target identity
#   (--to-name / --to-email).
#
# WARNING — Impact of history rewrite:
#   - Commit SHAs: all rewritten commits (and descendants) get NEW SHAs.
#   - Branch tips: branches will point to new commits; force-push required.
#   - Tags: lightweight and annotated tags move; signed tags/signatures break.
#   - GPG-signed commits: signatures become invalid.
#   - Open PRs/status checks: references to old SHAs won't match; may need recreating.
#   - Collaborators: must reset/rebase to new history (or reclone).
#   - Scripts/docs: any hardcoded SHAs become stale.
#   - Submodules: if this repo is a submodule, parent repos must update pointers.
#
# Note on tags after rewrite:
#   - Remote push can fail with "would clobber existing tag" if a tag points at
#     an old commit. Delete the remote tag and push the updated local tag:
#       git push --delete origin <tag>
#       git push origin <tag>
#
# Options (ALL required except --backup-dir):
#   --from "<selector>[,<selector>...]"  each selector may be:
#       - Name
#       - email@example.com
#     Note: the "Name <email>" form is NOT supported.
#   --to-name NEW_NAME           replacement author/committer name
#   --to-email NEW_EMAIL         replacement email
#   --backup-dir PATH            (optional) override backup mirror directory
#   --preview                    show matching commits only; no rewrite performed
#
# Backup (if --backup-dir omitted):
#   ../<repo>.rewrite-backup.<n>  first unused positive integer n.
#
# Examples:
#   Preview:
#     bash scripts/rewrite-authors.sh --from "David.May@fiery.com,David May,David" --to-name davfive --to-email davfive@gmail.com --preview
#   Full rewrite:
#     bash scripts/rewrite-authors.sh --from "David.May@fiery.com,David May,David" --to-name davfive --to-email davfive@gmail.com
#
# Afterward:
#   Script automates local cleanup and verification; prints commands for remote push.
# -----------------------------------------------------------------------------
set -euo pipefail

runx() { ( set -x; "$@" ); }

usage() {
  cat >&2 <<'EOF'
*** This operation rewrites history; review script header warnings. ***

Usage:
  rewrite-authors.sh --from "sel1,sel2" --to-name NEW_NAME --to-email NEW_EMAIL [--backup-dir PATH] [--preview]

--from selectors:
  Each selector may be a Name or an email. The "Name <email>" form is not supported.

Required:
  --from        Comma-separated selectors to match (name/email)
  --to-name     Replacement name
  --to-email    Replacement email

Optional:
  --backup-dir  Override backup directory (default ../<repo>.rewrite-backup.<n>)
  --preview     Show matching commits only; do not rewrite

Afterward (manual push):
  Script will print commands for remote operations.
EOF
  exit 2
}

# Globals
FROM_NAMES=""
TO_NAME=""
TO_EMAIL=""
BACKUP_DIR=""
FROM_LIST=""
FROM_EMAIL_LIST=""
PREVIEW=0

parse_args() {
  [[ $# -eq 0 ]] && usage
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from)       [[ $# -lt 2 ]] && usage; FROM_NAMES="$2"; shift 2 ;;
      --to-name)    [[ $# -lt 2 ]] && usage; TO_NAME="$2"; shift 2 ;;
      --to-email)   [[ $# -lt 2 ]] && usage; TO_EMAIL="$2"; shift 2 ;;
      --backup-dir) [[ $# -lt 2 ]] && usage; BACKUP_DIR="$2"; shift 2 ;;
      --preview)    PREVIEW=1; shift ;;
      --) shift; break ;;
      --help|-h) usage ;;
      --*) echo "Error: Unknown option $1" >&2; usage ;;
      *) echo "Error: unexpected positional argument $1" >&2; usage ;;
    esac
  done
  [[ -n "$FROM_NAMES" ]] || { echo "Error: --from missing" >&2; usage; }
  [[ -n "$TO_NAME"    ]] || { echo "Error: --to-name missing" >&2; usage; }
  [[ -n "$TO_EMAIL"   ]] || { echo "Error: --to-email missing" >&2; usage; }
}

build_match_lists() {
  FROM_LIST=""
  FROM_EMAIL_LIST=""
  local -a arr
  IFS=',' read -r -a arr <<< "$FROM_NAMES"
  for tok in "${arr[@]}"; do
    local t
    t="$(echo "$tok" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [[ -z "$t" ]] && continue
    if [[ "$t" == *"<"* || "$t" == *">"* ]]; then
      echo 'Error: "Name <email>" syntax is not supported; pass name or email only.' >&2
      exit 1
    fi
    if [[ "$t" == *"@"* ]]; then
      FROM_EMAIL_LIST+="$t"$'\n'
    else
      FROM_LIST+="$t"$'\n'
    fi
  done
  [[ -n "$FROM_LIST$FROM_EMAIL_LIST" ]] || { echo "Error: No valid names/emails parsed from --from" >&2; exit 1; }
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
  echo "Creating mirror backup at: $BACKUP_DIR"
  runx git clone --mirror . "$BACKUP_DIR"
}

preview_matches() {
  echo "Preview: commits to be rewritten"
  local tmp all
  tmp="$(mktemp -t rewrite-authors-preview.XXXXXX)"
  all="$(mktemp -t rewrite-authors-all.XXXXXX)"
  trap 'rm -f "${tmp-}" "${all-}"' EXIT

  git log --all --no-decorate --no-color \
    --pretty='%h|%an|%ae|%cn|%ce|%cI|%s' >"$all"

  if [[ -n "$FROM_LIST" ]]; then
    while IFS= read -r n; do
      [[ -z "$n" ]] && continue
      awk -F'|' -v n="$n" '$2==n || $4==n' "$all" >>"$tmp"
    done <<< "$FROM_LIST"
  fi

  if [[ -n "$FROM_EMAIL_LIST" ]]; then
    while IFS= read -r e; do
      [[ -z "$e" ]] && continue
      awk -F'|' -v e="$e" '$3==e || $5==e' "$all" >>"$tmp"
    done <<< "$FROM_EMAIL_LIST"
  fi

  if [[ ! -s "$tmp" ]]; then
    echo "Preview: no matching commits found."
    return
  fi

  local count
  count="$(sort -u "$tmp" | wc -l | tr -d ' ')"
  echo "Preview: matching commits ($count)"
  sort -u "$tmp" | awk -F'|' '{ printf "%s %s <%s> | %s | %s\n", $1, $2, $3, $6, $7 }'
}

run_rewrite() {
  echo "[DEBUG] Starting git filter-branch at $(date '+%H:%M:%S')"
  echo "Commit count before rewrite:"
  git rev-list --all --count

  echo "[DEBUG] Building env-filter script..."
  runx git filter-branch -f --env-filter "
# Match by exact name(s)
while IFS= read -r SRC; do
  [ -z \"\$SRC\" ] && continue
  if [ \"\$GIT_AUTHOR_NAME\" = \"\$SRC\" ]; then
    echo \"[filter-branch] Rewriting author name: \$SRC -> ${TO_NAME}\" >&2
    GIT_AUTHOR_NAME='${TO_NAME}'
    GIT_AUTHOR_EMAIL='${TO_EMAIL}'
  fi
  if [ \"\$GIT_COMMITTER_NAME\" = \"\$SRC\" ]; then
    echo \"[filter-branch] Rewriting committer name: \$SRC -> ${TO_NAME}\" >&2
    GIT_COMMITTER_NAME='${TO_NAME}'
    GIT_COMMITTER_EMAIL='${TO_EMAIL}'
  fi
done <<'NAMES'
${FROM_LIST}
NAMES

# Match by exact email(s)
while IFS= read -r SRC; do
  [ -z \"\$SRC\" ] && continue
  if [ \"\$GIT_AUTHOR_EMAIL\" = \"\$SRC\" ]; then
    echo \"[filter-branch] Rewriting author email: \$SRC -> ${TO_EMAIL}\" >&2
    GIT_AUTHOR_NAME='${TO_NAME}'
    GIT_AUTHOR_EMAIL='${TO_EMAIL}'
  fi
  if [ \"\$GIT_COMMITTER_EMAIL\" = \"\$SRC\" ]; then
    echo \"[filter-branch] Rewriting committer email: \$SRC -> ${TO_EMAIL}\" >&2
    GIT_COMMITTER_NAME='${TO_NAME}'
    GIT_COMMITTER_EMAIL='${TO_EMAIL}'
  fi
done <<'EMAILS'
${FROM_EMAIL_LIST}
EMAILS
" --tag-name-filter cat -- --all

  echo "[DEBUG] Completed at $(date '+%H:%M:%S')"
  echo "[DEBUG] Cleaning up refs/original..."
  runx rm -rf .git/refs/original
  runx git reflog expire --expire=now --all
  runx git gc --prune=now --aggressive

  echo "Commit count after rewrite:"
  git rev-list --all --count
}

verify() {
  echo "Verification: checking for remaining old identities..."
  local remaining=0

  if [[ -n "$FROM_LIST" ]]; then
    while IFS= read -r n; do
      [[ -z "$n" ]] && continue
      local count
      count=$(git log --all --pretty='%an|%cn' | grep -Fx "$n" || true | wc -l | tr -d ' ')
      if [[ $count -gt 0 ]]; then
        echo "WARNING: $count commits still reference name: $n"
        remaining=$((remaining + count))
      fi
    done <<< "$FROM_LIST"
  fi

  if [[ -n "$FROM_EMAIL_LIST" ]]; then
    while IFS= read -r e; do
      [[ -z "$e" ]] && continue
      local count
      count=$(git log --all --pretty='%ae|%ce' | grep -Fx "$e" || true | wc -l | tr -d ' ')
      if [[ $count -gt 0 ]]; then
        echo "WARNING: $count commits still reference email: $e"
        remaining=$((remaining + count))
      fi
    done <<< "$FROM_EMAIL_LIST"
  fi

  if [[ $remaining -eq 0 ]]; then
    echo "✓ All old identities successfully rewritten."
  else
    echo "⚠ $remaining commit references remain."
    exit 1
  fi
}

post_rewrite_local_cleanup() {
  echo
  echo "Running automated local cleanup..."
  
  # Because: fetch updates remote-tracking refs without modifying remote
  echo "Fetching from remote..."
  runx git fetch --all --tags || echo "Warning: fetch failed; continuing anyway"
  
  # Because: verify locally that old identities are gone
  echo "Final verification check..."
  local check_failed=0
  
  if [[ -n "$FROM_LIST" ]]; then
    while IFS= read -r n; do
      [[ -z "$n" ]] && continue
      if git log --all --pretty='%an|%cn' | grep -Fxq "$n"; then
        echo "ERROR: Found remaining name: $n"
        check_failed=1
      fi
    done <<< "$FROM_LIST"
  fi
  
  if [[ -n "$FROM_EMAIL_LIST" ]]; then
    while IFS= read -r e; do
      [[ -z "$e" ]] && continue
      if git log --all --pretty='%ae|%ce' | grep -Fxq "$e"; then
        echo "ERROR: Found remaining email: $e"
        check_failed=1
      fi
    done <<< "$FROM_EMAIL_LIST"
  fi
  
  if [[ $check_failed -eq 0 ]]; then
    echo "✓ Verification passed: no old identities remain locally."
  else
    echo "⚠ Verification found remaining old identities."
    exit 1
  fi
}

build_tag_conflict_list() {
  # Build regex pattern from FROM_LIST and FROM_EMAIL_LIST
  local pattern=""
  
  if [[ -n "$FROM_LIST" ]]; then
    while IFS= read -r n; do
      [[ -z "$n" ]] && continue
      if [[ -z "$pattern" ]]; then
        pattern="$n"
      else
        pattern="$pattern|$n"
      fi
    done <<< "$FROM_LIST"
  fi
  
  if [[ -n "$FROM_EMAIL_LIST" ]]; then
    while IFS= read -r e; do
      [[ -z "$e" ]] && continue
      if [[ -z "$pattern" ]]; then
        pattern="$e"
      else
        pattern="$pattern|$e"
      fi
    done <<< "$FROM_EMAIL_LIST"
  fi
  
  if [[ -z "$pattern" ]]; then
    echo ""
    return
  fi
  
  # Find tags that reference old identities
  git log --tags --no-walk --pretty='%D|%an|%ae|%cn|%ce' 2>/dev/null | \
    grep -E "$pattern" | \
    sed 's/tag: //g' | \
    awk -F'|' '{print $1}' | \
    tr ',' '\n' | \
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
    grep -v '^$' || true
}

echo_push_instruction() {
  echo
  echo "=========================================="
  echo "Local rewrite complete!"
  echo "=========================================="
  echo
  echo "To push rewritten history to remote, run:"
  echo
  
  # Check for conflicting tags
  local conflicting_tags
  conflicting_tags="$(build_tag_conflict_list)"
  
  if [[ -n "$conflicting_tags" ]]; then
    echo "# Because: these tags point to rewritten commits and will conflict"
    echo "# Delete conflicting tags on remote first:"
    while IFS= read -r tag; do
      [[ -z "$tag" ]] && continue
      echo "git push --delete origin '$tag' || true"
    done <<< "$conflicting_tags"
    echo
  fi
  
  cat <<'PUSHSCRIPT'
# Because: force-push rewritten main branch to GitHub
git push --force-with-lease origin main

PUSHSCRIPT

  if [[ -n "$conflicting_tags" ]]; then
    echo "# Because: re-push the updated tags after deleting conflicts"
    while IFS= read -r tag; do
      [[ -z "$tag" ]] && continue
      echo "git push origin '$tag'"
    done <<< "$conflicting_tags"
    echo
  fi

  cat <<'PUSHSCRIPT'
# Because: push all remaining tags
git push --tags

PUSHSCRIPT

  echo
  echo "Afterward: Check GitHub contributor graph in ~24 hours (caching delay)."
  echo
}

main() {
  parse_args "$@"
  build_match_lists

  if [[ $PREVIEW -eq 1 ]]; then
    preview_matches
    exit 0
  fi

  allocate_backup_dir
  mirror_backup
  run_rewrite
  verify
  post_rewrite_local_cleanup
  echo_push_instruction
}

main "$@"
# -----------------------------------------------------------------------------
