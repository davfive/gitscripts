#!/usr/bin/env bash
set -eu
# Converted from alias: my-branch-create
# Usage: branch-create.sh <branch-name>
allBranches=$(git branch -a \
  | sed 's|^\* ||' \
  | grep -v '/HEAD ->' \
  | sed 's|remotes/.*/||' \
  | sed 's|^  ||' \
  | sort | uniq)

if [ $# -ne 1 ]; then
  echo 'usage: branch-create.sh <branch-name-to-create>'
  exit 1
fi

if echo "$allBranches" | grep -w -q -- "$1"; then
  echo 'Branch already exists'
  exit 1
fi

echo "Creating new branch: \"$1\""
set -x
git checkout -b "$1" && git push --set-upstream origin "$1"