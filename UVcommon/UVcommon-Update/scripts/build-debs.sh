#!/usr/bin/env bash
# Construye todos los .deb en out/main y out/apps (dentro de update/UVcommon)
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
export SOURCE_DATE_EPOCH=1700000000   # builds reproducibles
rm -rf out && mkdir -p out/main out/apps

KEYFILE=common/uvos-archive-keyring/usr/share/keyrings/uvos-archive-keyring.gpg
if [ -n "${GPG_PUBLIC_KEY:-}" ]; then
  printf '%s\n' "$GPG_PUBLIC_KEY" | gpg --dearmor > "$KEYFILE"
elif [ -n "${GPG_KEYID:-}" ]; then
  gpg --export "$GPG_KEYID" > "$KEYFILE"
fi
[ -s "$KEYFILE" ] || { echo "ERROR: falta la clave publica (define GPG_PUBLIC_KEY o GPG_KEYID)"; exit 1; }

for dir in common/*/ profiles/*/; do
  [ -f "$dir/DEBIAN/control" ] && dpkg-deb --build --root-owner-group "$dir" out/main/
done
for dir in apps/*/; do
  [ -f "$dir/DEBIAN/control" ] && dpkg-deb --build --root-owner-group "$dir" out/apps/
done
ls -l out/*
