#!/usr/bin/env bash
set -eu
# Usage: diff-select.sh [fromRef]
PS3='Select one: '
echo 'Diff File:'
opts="$@"
files=$(git diff --name-only "$1")
if [ -z "$files" ]; then
  echo "No files to diff."
  exit 0
fi

select file in $files; do
  if [ -n "$file" ]; then
    set -x
    git diff $opts "$file"
  fi
  break
done