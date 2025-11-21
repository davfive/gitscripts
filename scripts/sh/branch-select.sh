#!/usr/bin/env bash
set -eu
# Interactive branch switcher (local first, then option to list all)
PS3='Select one: '

currentBranch=$(git branch 2>/dev/null | sed -n 's/^\* //p' || true)
localBranches=$(git branch 2>/dev/null | sed 's/^\* //' | sort || true)
listAll='**List-All**'

echo 'Local branches:'
# Show local branches and offer a choice, with a sentinel for listing all
options=$(printf "%s\n%s\n" "$localBranches" "$listAll")
select branch in $options; do
  if [ "$branch" = "$listAll" ]; then
    echo 'All Branches: (fetching first)'
    # fetch refs then list branches (dedup)
    git fetch 2>/dev/null || true
    allBranches=$(git branch -a | sed 's|^\* ||' | grep -v '/HEAD ->' | sed 's|remotes/.*/||' | sed 's|^  ||' | sort | uniq)
    # remove current branch from choices if present
    choices=$(printf "%s\n" "$allBranches" | awk -v cur="$currentBranch" '$0 != cur')
    echo "Choose one from all branches:"
    select branch in $choices; do
      if [ -n "$branch" ]; then
        set -x
        git checkout "$branch"
      fi
      break
    done
  else
    if [ -n "$branch" ]; then
      set -x
      git checkout "$branch"
    fi
  fi
  break
done