#!/usr/bin/env bash
# Promueve testing -> stable. Uso: promote.sh <dir-repo> [paquete ...]
# Sin paquetes, promueve todo lo que hay en testing.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REPO=$(realpath -m "${1:?falta directorio del repo}"); shift || true
mkdir -p "$REPO/conf"; cp "$ROOT"/repo/conf/* "$REPO/conf/"
if [ "$#" -gt 0 ]; then pkgs=("$@"); else
  mapfile -t pkgs < <(reprepro -b "$REPO" list testing | awk '{print $2}' | sort -u)
fi
[ "${#pkgs[@]}" -gt 0 ] || { echo "Nada que promover"; exit 0; }
reprepro -b "$REPO" copy stable testing "${pkgs[@]}"
