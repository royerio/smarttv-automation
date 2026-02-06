#!/bin/bash
# install.sh - Instala y configura la automatización de Smart TV

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="/usr/local/bin/smarttv"
CONFIG_DIR="/etc/smarttv-automation"
SYSTEMD_DIR="/etc/systemd/system"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
echo_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo_error "Este script debe ejecutarse como root"
    exit 1
fi

echo_info "=== Instalando Smart TV Automation ==="

# 1. Crear directorios
echo_info "Creando directorios..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "/var/log/smarttv-automation"

# 2. Copiar scripts
echo_info "Copiando scripts..."
cp "$SCRIPT_DIR/scripts/"*.sh "$INSTALL_DIR/"
cp "$SCRIPT_DIR/scripts/common-functions.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR"/*.sh

# 3. Copiar configuración
echo_info "Copiando configuración..."
cp "$SCRIPT_DIR/config/smarttv.conf" "$CONFIG_DIR/"
chmod 644 "$CONFIG_DIR/smarttv.conf"

# 4. Copiar servicios systemd
echo_info "Instalando servicios systemd..."
cp "$SCRIPT_DIR/systemd/"*.service "$SYSTEMD_DIR/"
chmod 644 "$SYSTEMD_DIR/adb-autoreconnect.service"
chmod 644 "$SYSTEMD_DIR/ir-protocol.service"
chmod 644 "$SYSTEMD_DIR/ir-listener.service"

# 5. Recargar daemon
echo_info "Recargando systemd daemon..."
systemctl daemon-reload

# 6. Habilitar servicios
echo_info "Habilitando servicios..."
systemctl enable adb-autoreconnect.service
systemctl enable ir-protocol.service
systemctl enable ir-listener.service

# 7. Iniciar servicios
echo_info "Iniciando servicios..."
systemctl start adb-autoreconnect.service
systemctl start ir-protocol.service
systemctl start ir-listener.service

echo_info "✓ Instalación completada"
echo ""
echo_info "Próximos pasos:"
echo "  1. Verificar estado: systemctl status adb-autoreconnect.service"
echo "  2. Ver logs: journalctl -u adb-autoreconnect.service -f"
echo "  3. Ejecutar diagnóstico: $SCRIPT_DIR/bin/diagnose.sh"