#!/usr/bin/env sh
set -eu
# Converted from alias: my-history-binary
# Show binary hash history for a given path
if [ $# -ne 1 ]; then
  echo "usage: history-binary.sh <path>" >&2
  exit 1
fi

echo '===================================================================================='
echo "$1: binary hash history"
echo '===================================================================================='
for hash in $(git rev-list --all --objects -- "$1" | grep "$1" | awk '{ print $1 }'); do
  echo "$1:$hash"
done