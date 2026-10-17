#!/usr/bin/env bash
# subir-version.sh - Cambia la version de los paquetes UVSO de una sola vez.
#
# Uso:  bash scripts/subir-version.sh [-n] [-f] [-d DIR] VERSION [paquete ...]
#
#   VERSION   0.0.4-alpha | "0.0.4 alpha" | 0.0.4-alpha2 | 0.0.4 (final)
#   paquete   (opcional) solo estos paquetes; sin nada = todos los que encuentre
#   -n        simulacion: muestra que cambiaria, sin tocar nada
#   -f        permite versiones que NO suben (APT no las vera como update)
#   -d DIR    carpeta donde buscar (por defecto, la actual)
#
# Ejemplos:
#   bash scripts/subir-version.sh 0.0.4-alpha
#   bash scripts/subir-version.sh -n 0.0.4-alpha
#   bash scripts/subir-version.sh 0.0.4-alpha2 uvso-uva-boot uvso-uva-base
set -euo pipefail

DRY=0; FORCE=0; DIR=.
uso() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }
while getopts ":nfd:h" o; do
  case $o in
    n) DRY=1 ;; f) FORCE=1 ;; d) DIR=$OPTARG ;;
    h) uso; exit 0 ;;
    *) uso >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
[ $# -ge 1 ] || { uso >&2; exit 1; }
RAW=$(printf '%s' "$1" | tr 'A-Z' 'a-z' | sed 's/^v//'); shift
PKGS=("$@")

# ---- interpretar la version ----
re='^([0-9]+\.[0-9]+\.[0-9]+)[-~ ]?(alpha|beta|rc)?([0-9]*)$'
if ! [[ $RAW =~ $re ]]; then
  echo "ERROR: version no valida: '$RAW' (ejemplos: 0.0.4-alpha, 0.0.4-alpha2, 0.0.4)" >&2; exit 1
fi
NUM=${BASH_REMATCH[1]}; STAGE=${BASH_REMATCH[2]}; N=${BASH_REMATCH[3]}
[ -z "$STAGE" ] && [ -n "$N" ] && { echo "ERROR: numero de pre-lanzamiento sin alpha/beta/rc" >&2; exit 1; }

if [ -n "$STAGE" ]; then
  DEB="$NUM~$STAGE${N:-1}"                       # lo que lee APT
  HUMAN="$NUM $STAGE"; [ "${N:-1}" -ge 2 ] && HUMAN="$HUMAN$N"   # lo que ve el usuario
  TAG="v$NUM-$STAGE"; [ "${N:-1}" -ge 2 ] && TAG="$TAG$N"
else
  DEB="$NUM"; HUMAN="$NUM"; TAG="v$NUM"
fi

# ---- buscar paquetes ----
mapfile -d '' CONTROLS < <(find "$DIR" \
  \( -name .git -o -name cache -o -name chroot -o -name binary -o -name out -o -name node_modules \) -prune \
  -o -path '*/DEBIAN/control' -type f -print0 | sort -z)

SEL=(); PROBLEMAS=0
printf '%-28s %-18s -> %s\n' "PAQUETE" "ACTUAL" "NUEVA"
for c in "${CONTROLS[@]}"; do
  pkg=$(awk -F': *' '/^Package:/{print $2; exit}' "$c")
  old=$(awk -F': *' '/^Version:/{print $2; exit}' "$c")
  if [ ${#PKGS[@]} -gt 0 ]; then
    hit=0; for p in "${PKGS[@]}"; do [ "$p" = "$pkg" ] && hit=1; done
    [ $hit -eq 1 ] || continue
  fi
  nota=""
  if ! dpkg --compare-versions "$DEB" gt "$old"; then nota="  <-- NO SUBE"; PROBLEMAS=1; fi
  printf '%-28s %-18s -> %s%s\n' "$pkg" "$old" "$DEB" "$nota"
  SEL+=("$c")
done

[ ${#SEL[@]} -gt 0 ] || { echo "No se encontro ningun paquete (revisa -d y los nombres)." >&2; exit 1; }
for p in "${PKGS[@]}"; do
  grep -rqs "^Package: $p\$" "${SEL[@]}" || echo "AVISO: no se encontro el paquete '$p'" >&2
done
if [ $PROBLEMAS -eq 1 ] && [ $FORCE -eq 0 ]; then
  echo; echo "ERROR: hay versiones que no son mayores que la actual; APT no las ofreceria como actualizacion." >&2
  echo "Usa una version mayor, o -f si de verdad quieres forzarlo." >&2; exit 1
fi
[ $DRY -eq 1 ] && { echo; echo "(simulacion: no se cambio nada)"; exit 0; }

# ---- aplicar ----
TOCADOS=()
for c in "${SEL[@]}"; do
  pdir=$(dirname "$(dirname "$c")")
  sed -i "s/^Version:.*/Version: $DEB/" "$c"; TOCADOS+=("$c")
  # os-release propio del paquete (nombre/version que ve el usuario)
  while IFS= read -r -d '' f; do
    sed -i -E \
      -e "/^(PRETTY_NAME|VERSION)=/ s/[0-9]+\.[0-9]+\.[0-9]+( (alpha|beta|rc)[0-9]*)?/$HUMAN/" \
      -e "/^VERSION_ID=/ s/[0-9]+\.[0-9]+\.[0-9]+/$NUM/" "$f"
    TOCADOS+=("$f")
  done < <(find "$pdir" -path '*/usr/lib/os-release' -type f -print0)
  # archivos de version dentro del paquete
  while IFS= read -r -d '' f; do
    printf '%s\n' "$DEB" > "$f"; TOCADOS+=("$f")
  done < <(find "$pdir" \( -path '*/usr/share/uvso/version' -o -path '*/usr/share/uvso/branding-version' \) -type f -print0)
done

echo; echo "Listo: ${#SEL[@]} paquete(s) a $DEB  (version visible: $HUMAN)"
echo; echo "Repos con cambios (haz commit y push en cada uno):"
for f in "${TOCADOS[@]}"; do git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null || true; done | sort -u | sed 's/^/  - /'
cat <<MSG

Siguientes pasos:
  git add -A && git commit -m "Version $HUMAN" && git push      (en cada repo de arriba)
  Si cambiaste submodulos, actualiza el puntero en el paraguas (UV-SO).
  Cuando la ISO este lista: git tag $TAG && git push --tags
  Recuerda poner $HUMAN en --iso-volume / --image-name de UVa-ISO (auto/config).
MSG
