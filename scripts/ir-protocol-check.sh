#!/bin/bash
# ir-protocol-check.sh - Configura protocolo IR con reintentos y validación

set -euo pipefail

# Cargar configuración y funciones comunes
source /etc/smarttv-automation/smarttv.conf || exit 1
source "$COMMON_FUNCTIONS" || exit 1

trap cleanup EXIT

# Verificar que se ejecuta como root
require_root || exit 1

# Verificar dependencias
check_dependencies ir-keytable || exit 1

log_info "=== Iniciando IR Protocol Configuration ==="

# Esperar a que el dispositivo IR esté listo
log_info "Esperando dispositivo IR: $IR_DEVICE"
if ! wait_for_ir_device "$IR_DEVICE" 30; then
    log_error "Dispositivo IR no se conectó en el tiempo especificado"
    exit 1
fi

log_info "Configurando protocolo NEC..."

local success=0

for attempt in $(seq 1 "$IR_RETRIES"); do
    log_info "Intento $attempt/$IR_RETRIES..."
    
    if run_command "$IR_KEYTABLE -s rc0 -p $IR_PROTOCOL" \
        "Falló configurar IR en intento $attempt"; then
        
        log_info "✓ Protocolo IR configurado exitosamente"
        success=1
        break
    fi
    
    if [[ $attempt -lt $IR_RETRIES ]]; then
        log_debug "Esperando ${IR_RETRY_DELAY}s antes de reintentar..."
        sleep "$IR_RETRY_DELAY"
    fi
done

if [[ $success -eq 0 ]]; then
    log_error "Falló configurar protocolo IR después de $IR_RETRIES intentos"
    exit 1
fi

log_info "=== Configuración IR completada ==="
exit 0