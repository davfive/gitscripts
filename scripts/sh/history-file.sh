#!/usr/bin/env sh
set -eu
# Converted from alias: my-history-file
# Dump history of a file
if [ $# -ne 1 ]; then
  echo "usage: history-file.sh <path>" >&2
  exit 1
fi

for hash in $(git rev-list --all --objects -- "$1" | grep "$1" | awk '{ print $1 }'); do
  echo '===================================================================================='
  echo "cat-file $1:$hash"
  echo '===================================================================================='
  git cat-file -p "$hash"
done