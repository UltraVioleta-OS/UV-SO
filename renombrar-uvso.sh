#!/usr/bin/env bash
# Renombra uvso -> uvso (contenido y nombres) en el repo donde se ejecute.
# Uso: desde la raiz de un repo:  bash renombrar-uvso.sh
set -euo pipefail

# 1) contenido de archivos de texto (ignora binarios y .git)
find . -name .git -prune -o -type f -print0 \
  | xargs -0 grep -IlZs -e uvso -e UVSO -e Uvso \
  | xargs -0 -r sed -i 's/uvso/uvso/g; s/UVSO/UVSO/g; s/Uvso/Uvso/g'

# 2) nombres de archivos y carpetas (primero los hijos)
find . -name .git -prune -o -depth -iname '*uvso*' -print0 \
  | while IFS= read -r -d '' p; do
      d=$(dirname "$p"); b=$(basename "$p")
      n=$(printf '%s' "$b" | sed 's/uvso/uvso/g; s/UVSO/UVSO/g; s/Uvso/Uvso/g')
      mv "$p" "$d/$n"
    done

echo "Hecho. Revisa con: grep -rIni uvso . --exclude-dir=.git"
