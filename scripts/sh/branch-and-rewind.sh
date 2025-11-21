#!/usr/bin/env sh
set -eu
git checkout main
git pull --ff-only
git branch -D tmp || true