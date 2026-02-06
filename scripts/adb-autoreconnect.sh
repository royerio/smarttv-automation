#!/bin/bash
# adb-autoreconnect.sh - Mantiene conexión ADB activa

set -euo pipefail

# Cargar configuración y funciones comunes
source /etc/smarttv-automation/smarttv.conf || {
    echo "ERROR: No se pudo cargar configuración" >&2
    exit 1
}
source "$COMMON_FUNCTIONS" || {
    echo "ERROR: No se pudo cargar funciones comunes" >&2
    exit 1
}

trap cleanup EXIT

# Verificar dependencias
check_dependencies adb || exit 1

log_info "=== Iniciando ADB Auto-Reconnect Service ==="
log_info "Target: $ADB_TARGET"

local_connect() {
    log_info "Intentando conectar a $ADB_TARGET..."
    
    if run_with_timeout "$ADB_CONNECT_TIMEOUT" \
        "$ADB_COMMAND connect $ADB_TARGET" >/dev/null 2>&1; then
        log_info "✓ Conexión ADB establecida"
        return 0
    else
        log_warning "✗ Falló conexión ADB"
        return 1
    fi
}

main_loop() {
    local was_connected=0
    
    while true; do
        # Verificar conexión actual
        if $ADB_COMMAND devices 2>/dev/null | grep -q "$ADB_TARGET"; then
            if [[ $was_connected -eq 0 ]]; then
                log_info "★ ADB conectado después de desconexión"
                
                # Iniciar servicios dependientes
                if systemctl is-active --quiet ir-protocol.service; then
                    log_debug "ir-protocol.service ya está activo"
                else
                    log_info "Iniciando ir-protocol.service..."
                    systemctl start ir-protocol.service || log_warning "Falló al iniciar ir-protocol.service"
                fi
                
                # Esperar a que ir-protocol.service termine (Type=oneshot)
                log_debug "Esperando a ir-protocol.service..."
                sleep 3
                
                # Iniciar listener
                log_info "Iniciando ir-listener.service..."
                systemctl start ir-listener.service || log_warning "Falló al iniciar ir-listener.service"
                
                was_connected=1
            fi
        else
            if [[ $was_connected -eq 1 ]]; then
                log_warning "ADB desconectado"
                was_connected=0
            fi
            
            log_debug "Intentando reconectar..."
            local_connect
        fi
        
        sleep "$ADB_CHECK_INTERVAL"
    done
}

main_loop