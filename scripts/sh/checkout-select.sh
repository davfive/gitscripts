#!/usr/bin/env bash
set -eu
# Converted from alias: my-checkout-select
# Interactive revert (checkout -- <file>) selector
PS3='Select one: '
echo 'Revert file (git checkout -- <file>)'
files=$(git status -s | sed -e '/^[A-Z]/d' | awk '{print $2}')
if [ -z "$files" ]; then
  echo "No candidate files to revert."
  exit 0
fi

select file in $files; do
  if [ -n "$file" ]; then
    set -x
    git checkout -- "$file"
  fi
  break
done