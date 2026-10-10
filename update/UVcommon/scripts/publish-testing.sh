#!/usr/bin/env bash
# Uso: publish-testing.sh <dir-del-repo-apt>
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REPO=$(realpath -m "${1:?falta directorio del repo}")
mkdir -p "$REPO/conf"
cp "$ROOT"/repo/conf/* "$REPO/conf/"

for comp in main apps; do
  for deb in "$ROOT"/out/$comp/*.deb; do
    [ -e "$deb" ] || continue
    name=$(dpkg-deb -f "$deb" Package)
    ver=$(dpkg-deb -f "$deb" Version)
    if [ -n "$(reprepro -b "$REPO" listfilter testing "Package (== $name), Version (== $ver)")" ]; then
      echo "= $name $ver ya esta en testing, se omite"
      continue
    fi
    echo "+ $name $ver -> testing/$comp"
    reprepro -b "$REPO" -C "$comp" includedeb testing "$deb"
  done
done
