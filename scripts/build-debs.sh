#!/usr/bin/env bash
# Construye los .deb en out/main (packages/) y out/apps (apps/)
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
export SOURCE_DATE_EPOCH=1700000000   # builds reproducibles
rm -rf out && mkdir -p out/main out/apps

# /etc/os-release del paquete de branding debe ser SIEMPRE un enlace a
# /usr/lib/os-release (un zip o Windows lo convierten en archivo normal y
# se queda con el texto viejo). Se recrea aqui antes de construir.
if [ -f packages/uvso-uva-branding/usr/lib/os-release ]; then
  mkdir -p packages/uvso-uva-branding/etc
  ln -sfn ../usr/lib/os-release packages/uvso-uva-branding/etc/os-release
fi

for dir in packages/*/; do
  [ -f "$dir/DEBIAN/control" ] && dpkg-deb --build --root-owner-group "$dir" out/main/
done
for dir in apps/*/; do
  [ -f "$dir/DEBIAN/control" ] && dpkg-deb --build --root-owner-group "$dir" out/apps/
done
ls -l out/*
