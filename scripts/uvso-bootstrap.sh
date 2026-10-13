#!/usr/bin/env bash
# uvso-bootstrap.sh - Conecta un sistema UVSO ya instalado a los repos de
# Debian trixie y de UVSO (UV-SO comun + UVa-Update). Se ejecuta UNA vez.
#
# Uso:  sudo bash uvso-bootstrap.sh [stable|testing]     (por defecto: stable)
set -euo pipefail

CANAL=${1:-stable}
case "$CANAL" in stable|testing) ;; *) echo "Canal no valido: $CANAL (usa stable o testing)" >&2; exit 1 ;; esac

BASE="https://ultravioleta-os.github.io"
KEY_URL=${KEY_URL:-$BASE/UV-SO/uvso-archive-keyring.gpg}
# Huella de tu clave principal (40 caracteres, sin espacios). Se obtiene con:
#   gpg --list-keys --with-colons TU_CORREO | awk -F: '/^fpr/ {print $10; exit}'
EXPECTED_FPR="${UVSO_FPR:-F77C25DEFEA7F20F24690D9C8DE6797661F93894}"

R=${UVSO_ROOT:-}          # solo para pruebas; en uso normal queda vacio
if [ -z "$R" ] && [ "$(id -u)" -ne 0 ]; then echo "Ejecuta con sudo." >&2; exit 1; fi
log() { printf '\n==> %s\n' "$*"; }
apt_ok() { [ -z "$R" ]; }     # en pruebas no se llama a apt

# 1) Entradas de disco (cdrom:) fuera
log "Desactivando entradas de disco (cdrom:)"
for f in "$R/etc/apt/sources.list" "$R"/etc/apt/sources.list.d/*.list; do
  [ -f "$f" ] || continue
  sed -i -E 's/^((deb|deb-src)[[:space:]]+(\[[^]]*\][[:space:]]+)?cdrom:)/# [uvso] \1/' "$f"
done

# 2) Repos de Debian trixie
log "Configurando repos de Debian trixie"
install -d "$R/etc/apt/sources.list.d" "$R/usr/share/keyrings"
D="$R/etc/apt/sources.list.d/debian.sources"
[ -f "$D" ] && cp -a "$D" "$D.uvso-bak"
cat > "$D" <<'DEB'
Types: deb
URIs: http://deb.debian.org/debian/
Suites: trixie trixie-updates
Components: main contrib non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://deb.debian.org/debian-security/
Suites: trixie-security
Components: main contrib non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
DEB

# 3) Herramientas necesarias (curl/wget y gpg)
if apt_ok && { { ! command -v curl >/dev/null && ! command -v wget >/dev/null; } || ! command -v gpg >/dev/null; }; then
  log "Instalando curl y gnupg"
  apt-get update && apt-get install -y curl gnupg ca-certificates
fi

# 4) Descargar y VERIFICAR la clave
log "Descargando la clave de UVSO"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT; mkdir -m 700 "$TMP/gh"
if command -v curl >/dev/null; then curl -fsSL "$KEY_URL" -o "$TMP/key.gpg"
else wget -q "$KEY_URL" -O "$TMP/key.gpg"; fi
FPR=$(gpg --homedir "$TMP/gh" --batch --show-keys --with-colons "$TMP/key.gpg" 2>/dev/null | awk -F: '/^fpr/ {print $10; exit}' || true)
[ -n "$FPR" ] || { echo "ERROR: el archivo descargado no es una clave valida." >&2; exit 1; }
echo "Huella de la clave descargada: $FPR"
if [ -n "$EXPECTED_FPR" ]; then
  [ "$FPR" = "$EXPECTED_FPR" ] || { echo "ERROR: la huella NO coincide con la esperada ($EXPECTED_FPR). Abortando." >&2; exit 1; }
  echo "La huella coincide con la esperada."
else
  echo "(No hay huella esperada en el script. Compara la de arriba con la tuya.)"
  read -r -p "¿Es correcta? [s/N] " ok < /dev/tty
  [ "$ok" = "s" ] || [ "$ok" = "S" ] || { echo "Cancelado."; exit 1; }
fi
install -m 644 "$TMP/key.gpg" "$R/usr/share/keyrings/uvso-archive-keyring.gpg"

# 5) Repos de UVSO
log "Configurando los repos de UVSO ($CANAL)"
S="$R/etc/apt/sources.list.d"
if [ "$CANAL" = stable ]; then
  cat > "$S/uvso.sources" <<EOT
Types: deb
URIs: $BASE/UV-SO/
Suites: stable
Components: main apps
Signed-By: /usr/share/keyrings/uvso-archive-keyring.gpg
EOT
  cat > "$S/uvso-uva.sources" <<EOT
Types: deb
URIs: $BASE/UVa-Update/
Suites: stable
Components: main apps
Signed-By: /usr/share/keyrings/uvso-archive-keyring.gpg
EOT
else
  cat > "$S/uvso-testing.sources" <<EOT
Types: deb
URIs: $BASE/UV-SO/
Suites: testing
Components: main apps
Signed-By: /usr/share/keyrings/uvso-archive-keyring.gpg

Types: deb
URIs: $BASE/UVa-Update/
Suites: testing
Components: main apps
Signed-By: /usr/share/keyrings/uvso-archive-keyring.gpg
EOT
fi

# 6) Actualizar e instalar
if apt_ok; then
  log "apt update"
  apt-get update
  echo
  echo "Repos listos. Instalar uvso-uva-base ahora toca initramfs, GRUB y os-release."
  echo "Haz una copia o snapshot antes si es una maquina importante."
  read -r -p "¿Instalar uvso-uva-base ahora? [s/N] " r < /dev/tty
  if [ "$r" = "s" ] || [ "$r" = "S" ]; then apt-get install uvso-uva-base; fi
else
  log "(modo prueba: sin apt)"
fi
log "Listo."
