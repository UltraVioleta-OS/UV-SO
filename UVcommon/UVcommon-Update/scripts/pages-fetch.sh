#!/usr/bin/env bash
# Descarga (o crea) la rama gh-pages en el directorio dado
set -euo pipefail
DIR=${1:?}; URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
if git ls-remote --exit-code --heads "$URL" gh-pages >/dev/null 2>&1; then
  git clone --branch gh-pages --single-branch "$URL" "$DIR"
else
  mkdir -p "$DIR" && cd "$DIR" && git init -b gh-pages && git remote add origin "$URL"
fi
