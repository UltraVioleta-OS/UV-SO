#!/usr/bin/env bash
set -euo pipefail
cd "${1:?}"
touch .nojekyll
git config user.name "github-actions"; git config user.email "actions@users.noreply.github.com"
git add -A
git diff --cached --quiet && { echo "Sin cambios"; exit 0; }
git commit -m "${2:-Actualizar repo APT}"
git push origin gh-pages
