#!/bin/bash
# diagnose.sh - Diagnóstico de Smart TV Automation

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_ok() { echo -e "${GREEN}✓${NC} $*"; }
check_fail() { echo -e "${RED}✗${NC} $*"; }
check_warn() { echo -e "${YELLOW}⚠${NC} $*"; }
check_info() { echo -e "${BLUE}ℹ${NC} $*"; }

echo "=== Smart TV Automation Diagnostics ==="
echo ""

# 1. Verificar dependencias
echo -e "${BLUE}[Dependencias]${NC}"
for cmd in adb ir-keytable evtest systemctl; do
    if command -v "$cmd" >/dev/null 2>&1; then
        check_ok "$cmd instalado"
    else
        check_fail "$cmd NO encontrado"
    fi
done
echo ""

# 2. Verificar archivos
echo -e "${BLUE}[Archivos de Configuración]${NC}"
files=(
    "/etc/smarttv-automation/smarttv.conf"
    "/usr/local/bin/smarttv/adb-autoreconnect.sh"
    "/usr/local/bin/smarttv/ir-protocol-check.sh"
    "/usr/local/bin/smarttv/ir-listener.sh"
    "/usr/local/bin/smarttv/magis.sh"
)

for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
        check_ok "$file existe"
    else
        check_fail "$file NO existe"
    fi
done
echo ""

# 3. Verificar servicios
echo -e "${BLUE}[Servicios systemd]${NC}"
for service in adb-autoreconnect ir-protocol ir-listener; do
    if systemctl is-enabled "${service}.service" &>/dev/null; then
        status=$(systemctl is-active "${service}.service")
        if [[ "$status" == "active" ]]; then
            check_ok "${service}.service activo"
        else
            check_warn "${service}.service inactivo (estado: $status)"
        fi
    else
        check_fail "${service}.service no habilitado"
    fi
done
echo ""

# 4. Verificar ADB
echo -e "${BLUE}[ADB Connectivity]${NC}"
if command -v adb >/dev/null 2>&1; then
    devices=$(adb devices 2>/dev/null | tail -n +2)
    if [[ -z "$devices" ]]; then
        check_warn "Ningún dispositivo conectado"
        check_info "Ejecuta: adb connect 192.168.101.50:5555"
    else
        check_info "Dispositivos conectados:"
        echo "$devices" | sed 's/^/  /'
    fi
else
    check_fail "ADB no está instalado"
fi
echo ""

# 5. Verificar dispositivo IR
echo -e "${BLUE}[Dispositivo IR]${NC}"
if [[ -e "/dev/input/event0" ]]; then
    check_ok "Dispositivo IR (/dev/input/event0) disponible"
else
    check_fail "Dispositivo IR NO encontrado"
fi
echo ""

# 6. Verificar permisos
echo -e "${BLUE}[Permisos]${NC}"
user=$(whoami)
if [[ "$user" == "root" ]]; then
    check_ok "Se ejecuta como root"
else
    check_warn "Se ejecuta como $user (algunos comandos necesitan root)"
fi
echo ""

# 7. Ver logs recientes
echo -e "${BLUE}[Logs Recientes]${NC}"
echo "Últimas 5 líneas de adb-autoreconnect:"
journalctl -u adb-autoreconnect.service -n 5 --no-pager 2>/dev/null || check_warn "Sin logs disponibles"
echo ""

echo "=== Fin del diagnóstico ==="