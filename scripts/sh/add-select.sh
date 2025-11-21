#!/usr/bin/env bash
set -eu
# Usage: add-select.sh [files...]
if [ $# -gt 0 ]; then
  set -x
  git add "$@"
  exit $?
fi

PS3='Select one: '
echo 'Add File: '
# list changed files; let user choose one
files=$(git diff --name-only)
if [ -z "$files" ]; then
  echo "No changed files."
  exit 0
fi

select file in $files; do
  if [ -n "$file" ]; then
    set -x
    git add "$file"
  fi
  break
done