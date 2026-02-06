#!/bin/bash
# magis.sh - Navega a Magis y abre canal favoritos

set -euo pipefail

# Cargar configuración y funciones comunes
source /etc/smarttv-automation/smarttv.conf 2>/dev/null || {
    # Fallback si no está en /etc
    ADB_COMMAND="/usr/bin/adb"
    MAGIS_APP="com.android.mgstv"
    MAGIS_LOG="/var/log/magis.log"
}
source "$COMMON_FUNCTIONS" 2>/dev/null || {
    # Fallback simplificado sin funciones
    log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*" >> "$MAGIS_LOG"; }
    log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$MAGIS_LOG"; }
}

trap cleanup EXIT

log_info "=== Ejecutando magis.sh ==="

# Validar que ADB está disponible
if ! command -v "$ADB_COMMAND" >/dev/null 2>&1; then
    log_error "ADB no encontrado"
    exit 1
fi

# Función auxiliar para ejecutar comando ADB con validación
adb_cmd() {
    local description="$1"
    shift
    local cmd="$@"
    
    log_info "→ $description"
    
    if ! output=$($ADB_COMMAND $cmd 2>&1); then
        log_error "✗ Falló: $description"
        log_error "Output: $output"
        return 1
    fi
    
    return 0
}

# 1. Ir a home
adb_cmd "Ir a pantalla principal" shell input keyevent 3 || {
    log_error "Falló ir a home"
    exit 1
}
sleep 2

# 2. Lanzar aplicación Magis
adb_cmd "Lanzando Magis" shell monkey -p "$MAGIS_APP" -c android.intent.category.LAUNCHER 1 || {
    log_error "Falló lanzar Magis"
    exit 1
}
sleep 15

# 3. Dump de UI para detectar pop-ups
adb_cmd "Haciendo dump de UI" shell uiautomator dump "$UI_DUMP_PATH" || {
    log_error "Falló dump de UI"
    exit 1
}

# Pull local
if adb_cmd "Descargando XML" pull "$UI_DUMP_PATH" "$UI_LOCAL_PATH"; then
    # 4. Detectar y cerrar pop-up si existe
    if grep -q "mIvAd" "$UI_LOCAL_PATH" 2>/dev/null; then
        log_info "Pop-up detectado, cerrando..."
        adb_cmd "Presionando BACK" shell input keyevent 4 || true
        sleep 2
    else
        log_info "Sin pop-ups detectados"
    fi
else
    log_warning "No se pudo descargar XML, continuando..."
fi

sleep 2

# 5. Navegar a favoritos (3 derechas, 2 abajo, 1 derecha, OK)
adb_cmd "Navegando a favoritos" shell input keyevent 22 || true  # RIGHT
adb_cmd "Navegando..." shell input keyevent 20 || true           # DOWN
adb_cmd "Navegando..." shell input keyevent 22 || true           # RIGHT
adb_cmd "Navegando..." shell input keyevent 23 || true           # OK
sleep 3

# 6. Última navegación
adb_cmd "Finalizando navegación" shell input keyevent 22 || true # RIGHT
adb_cmd "Seleccionando favoritos" shell input keyevent 23 || true # OK

log_info "✓ magis.sh completado exitosamente"
exit 0