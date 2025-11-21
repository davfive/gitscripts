#!/usr/bin/env sh
set -eu
# Prints the likely parent branch
git show-branch -a \
  | grep '\*' \
  | grep -v "$(git rev-parse --abbrev-ref HEAD)" \
  | head -n1 \
  | sed 's/.*\[\(.*\)\].*/\1/' \
  | sed 's/[\^~].*//'