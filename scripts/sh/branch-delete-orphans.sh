#!/usr/bin/env bash
set -eu
echo "Fetching latest git references ..."
git fetch -p
echo
echo "Local branches with deleted remote:"
branches=$(git branch -vv | grep -v '^\*' | grep ': gone]' | awk '{print $1}')
if [ -z "$branches" ]; then
  echo "No orphaned local branches found."
  exit 0
fi

for branch in $branches; do
  echo
  echo "Delete local orphaned branch $branch?"
  PS3='Delete? '
  select yn in Yes No; do
    case "$yn" in
      Yes)
        git branch -D "$branch"
        break
        ;;
      No)
        break
        ;;
    esac
  done
done