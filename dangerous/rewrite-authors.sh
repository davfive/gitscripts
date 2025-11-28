#!/usr/bin/env bash
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
# Options (ALL required except --backup-dir):
#   --from "<selector>[,<selector>...]"  selectors to rewrite; each selector may be:
#       - Name
#       - email@example.com
#       - Name <email@example.com>
#   --to-name NEW_NAME           replacement author/committer name
#   --to-email NEW_EMAIL         replacement email
#   --backup-dir PATH            (optional) override backup mirror directory
#   --preview                    show matching commits only; no rewrite performed
#
# Backup (if --backup-dir omitted):
#   ../<repo>.rewrite-backup.<n>  first unused positive integer n.
#
# Examples:
#   Full history:
#     bash scripts/rewrite-authors.sh --from "David May,david@example.com" --to-name davfive --to-email davfive@gmail.com
#   Range-limited:
#     bash scripts/rewrite-authors.sh --from "David May <david@example.com>" --to-name davfive --to-email davfive@gmail.com v3.0.0-alpha..
#
# Afterward (manual push):
#   git push --force-with-lease origin main --tags
# -----------------------------------------------------------------------------
set -euo pipefail

# Scoped verbose executor
runx() { ( set -x; "$@" ); }

usage() {
  cat >&2 <<'EOF'
*** This operation rewrites history; review script header warnings. ***

Usage:
  rewrite-authors.sh --from "sel1,sel2" --to-name NEW_NAME --to-email NEW_EMAIL [--backup-dir PATH] [--preview] [<rev/range> ...]

--from selectors:
  Each selector may be a Name, an email, or "Name <email>"

Required:
  --from        Comma-separated selectors to match (name/email)
  --to-name     Replacement name
  --to-email    Replacement email

Optional:
  --backup-dir  Override backup directory (default ../<repo>.rewrite-backup.<n>)
  --preview     Show matching commits only; do not rewrite

Positional revision/range specs (optional):
  Examples: v1.0.0..  tagA..tagB  A..B  main  main ^feature

Afterward (manual push):
  git push --force-with-lease origin main --tags
EOF
  exit 2
}

# Globals
FROM_NAMES=""        # raw --from value
TO_NAME=""
TO_EMAIL=""
BACKUP_DIR=""
FROM_LIST=""         # newline-delimited names extracted from --from
FROM_EMAIL_LIST=""   # newline-delimited emails extracted from --from
RANGE_SPECS=()
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
      *) break ;;
    esac
  done
  RANGE_SPECS=("$@")
  [[ -n "$FROM_NAMES" ]] || { echo "Error: --from missing" >&2; usage; }
  [[ -n "$TO_NAME"    ]] || { echo "Error: --to-name missing" >&2; usage; }
  [[ -n "$TO_EMAIL"   ]] || { echo "Error: --to-email missing" >&2; usage; }
}

build_match_lists() {
  FROM_LIST=""
  FROM_EMAIL_LIST=""
  IFS=',' read -r -a arr <<< "$FROM_NAMES"
  for tok in "${arr[@]}"; do
    # trim surrounding whitespace
    t="$(echo "$tok" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [[ -z "$t" ]] && continue
    if [[ "$t" =~ <[^>]+> ]]; then
      # "Name <email>"
      name="${t%%<*}"
      name="$(echo "$name" | sed -E 's/[[:space:]]+$//')"
      email="$(echo "$t" | sed -E 's/.*<([^>]+)>.*/\1/')"
      [[ -n "$name"  ]] && FROM_LIST+="$name"$'\n'
      [[ -n "$email" ]] && FROM_EMAIL_LIST+="$email"$'\n'
    elif [[ "$t" == *"@"* ]]; then
      # email only
      FROM_EMAIL_LIST+="$t"$'\n'
    else
      # name only
      FROM_LIST+="$t"$'\n'
    fi
  done
  [[ -n "$FROM_LIST$FROM_EMAIL_LIST" ]] || { echo "Error: No valid names/emails parsed from --from" >&2; exit 1; }
}

# Build an anchored OR-regex from a newline list (returns empty if list empty)
or_regex_from_list() {
  local data="$1"
  local out=""
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # escape regex metacharacters
    local esc
    esc="$(printf '%s' "$line" | sed -E 's/([][(){}.^$+*?|\\])/\\\1/g')"
    if [[ -z "$out" ]]; then out="$esc"; else out="$out|$esc"; fi
  done <<< "$data"
  [[ -n "$out" ]] && printf '^(%s)$' "$out" || true
}

allocate_backup_dir() {
  if [[ -n "$BACKUP_DIR" ]]; then
    return
  fi
  local top repo i=1 cand
  top="$(runx git rev-parse --show-toplevel | tail -n1)"
  repo="$(basename "$top")"
  while :; do
    cand="../${repo}.rewrite-backup.${i}"
    [[ -e "$cand" ]] || { BACKUP_DIR="$cand"; break; }
    i=$((i+1))
  done
}

mirror_backup() {
  echo "Creating mirror backup at: $BACKUP_DIR"
  runx git clone --mirror . "$BACKUP_DIR" || true
}

preview_matches() {
  local rev_args=()
  if [[ ${#RANGE_SPECS[@]} -gt 0 ]]; then
    rev_args=("${RANGE_SPECS[@]}")
    echo "Preview range specs: ${RANGE_SPECS[*]}"
  else
    rev_args=(--all)
    echo "Preview over full history."
  fi

  local name_re email_re
  name_re="$(or_regex_from_list "$FROM_LIST" || true)"
  email_re="$(or_regex_from_list "$FROM_EMAIL_LIST" || true)"

  local tmp
  tmp="$(mktemp -t rewrite-authors-preview.XXXXXX)"
  trap 'rm -f "$tmp"' EXIT

  if [[ -n "${name_re:-}" ]]; then
    runx git log "${rev_args[@]}" --no-decorate --no-color \
      --author="$name_re" --pretty='%h %an <%ae> | %cI | %s' >>"$tmp"
    runx git log "${rev_args[@]}" --no-decorate --no-color \
      --committer="$name_re" --pretty='%h %an <%ae> | %cI | %s' >>"$tmp"
  fi
  if [[ -n "${email_re:-}" ]]; then
    runx git log "${rev_args[@]}" --no-decorate --no-color \
      --author="$email_re" --pretty='%h %an <%ae> | %cI | %s' >>"$tmp"
    runx git log "${rev_args[@]}" --no-decorate --no-color \
      --committer="$email_re" --pretty='%h %an <%ae> | %cI | %s' >>"$tmp"
  fi

  if [[ ! -s "$tmp" ]]; then
    echo "Preview: no matching commits found."
    return
  fi

  local count
  count="$(sort -u "$tmp" | wc -l | tr -d ' ')"
  echo "Preview: matching commits ($count)"
  sort -u "$tmp"
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
  runx git filter-branch --env-filter "
# Match by exact name(s)
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

# Match by exact email(s)
while IFS= read -r SRC; do
  [ -z \"\$SRC\" ] && continue
  if [ \"\$GIT_AUTHOR_EMAIL\" = \"\$SRC\" ]; then
    GIT_AUTHOR_NAME='${TO_NAME}'
    GIT_AUTHOR_EMAIL='${TO_EMAIL}'
  fi
  if [ \"\$GIT_COMMITTER_EMAIL\" = \"\$SRC\" ]; then
    GIT_COMMITTER_NAME='${TO_NAME}'
    GIT_COMMITTER_EMAIL='${TO_EMAIL}'
  fi
done <<'EMAILS'
${FROM_EMAIL_LIST}
EMAILS
" --tag-name-filter cat -- "${rev_args[@]}"
}

cleanup_repository() {
  runx rm -rf .git/refs/original || true
  runx bash -c "git for-each-ref --format='%(refname)' refs/original | xargs -r -n1 git update-ref -d" || true
  runx git reflog expire --expire=now --all
  runx git gc --prune=now --aggressive
}

verify() {
  echo "Remaining (author name) matches:"
  runx bash -c "git log --all --pretty='%an' | grep -Fx -f <(printf '%s' \"$FROM_LIST\" | sed '/^$/d') | wc -l" || true
  echo "Remaining (committer name) matches:"
  runx bash -c "git log --all --pretty='%cn' | grep -Fx -f <(printf '%s' \"$FROM_LIST\" | sed '/^$/d') | wc -l" || true
  echo "Remaining (author email) matches:"
  runx bash -c "git log --all --pretty='%ae' | grep -Fx -f <(printf '%s' \"$FROM_EMAIL_LIST\" | sed '/^$/d') | wc -l" || true
  echo "Remaining (committer email) matches:"
  runx bash -c "git log --all --pretty='%ce' | grep -Fx -f (printf '%s' \"$FROM_EMAIL_LIST\" | sed '/^$/d') | wc -l" || true
  echo "Sample rewritten commits:"
  runx git log --all --author="$TO_NAME" --pretty='%h %an <%ae>' | head || true
}

echo_push_instruction() {
  echo
  echo "To publish rewritten history run (manual step):"
  echo "git push --force-with-lease origin main --tags"
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
  run_filter_branch
  cleanup_repository
  verify
  echo_push_instruction
}

main "$@"
# -----------------------------------------------------------------------------
