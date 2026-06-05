#!/bin/bash
# ir-listener.sh - Listener para detectar tecla OK del control remoto

set -euo pipefail

# Cargar configuración y funciones comunes
source /etc/smarttv-automation/smarttv.conf || exit 1
source "$COMMON_FUNCTIONS" || exit 1

trap cleanup EXIT

# Verificar dependencias
# check_dependencies evtest || exit 1

log_info "=== Iniciando IR Remote Listener ==="
log_info "Dispositivo: $IR_DEVICE"
log_info "Script a ejecutar: $MAGIS_SCRIPT"

# Validar que el script magis existe
if [[ ! -f "$MAGIS_SCRIPT" ]]; then
    log_error "Script magis no encontrado: $MAGIS_SCRIPT"
    exit 1
fi

# Esperar a que dispositivo IR esté listo
if ! wait_for_ir_device "$IR_DEVICE" 30; then
    log_error "Dispositivo IR no disponible"
    exit 1
fi

# Esperar a que ADB esté disponible
if ! wait_for_adb "$ADB_TARGET" 30; then
    log_warning "ADB no disponible al iniciar listener (seguiremos intentando)"
fi

log_info "✓ Sistema listo, escuchando por pulsaciones de OK..."

# Función para manejar pulsación de OK
handle_ok_press() {
    log_info "🔘 Botón OK presionado, ejecutando magis.sh..."
    
    # Verificar que ADB está disponible antes de ejecutar magis
    if ! $ADB_COMMAND devices 2>/dev/null | grep -q "$ADB_TARGET"; then
        log_error "ADB no disponible, saltando ejecución de magis.sh"
        return 1
    fi
    
    # Ejecutar magis.sh
    if bash "$MAGIS_SCRIPT" >> "$MAGIS_LOG" 2>&1; then
        log_info "✓ magis.sh ejecutado exitosamente"
    else
        log_error "✗ magis.sh falló"
    fi
    
    # Rotar logs de magis si es necesario
    rotate_logs "$MAGIS_LOG"
}

# Main loop con timeout
main_loop() {
    # Ejecutar evtest con timeout para evitar cuelgues permanentes
    run_with_timeout "$EVTEST_TIMEOUT" \
        "/usr/bin/evtest '$IR_DEVICE' 2>/dev/null" | while read -r line; do
        
        # Buscar pulsación de tecla OK (código NEC: 0x200815, su valor decimal 2099221)
        if echo "$line" | grep -qi "MSC_SCAN.*200815"; then
            handle_ok_press
        fi
        if echo "$line" | grep -qi "MSC_SCAN.*0x200815"; then
            handle_ok_press
        fi
        if echo "$line" | grep -qi "MSC_SCAN.*2099221"; then
            handle_ok_press
        fi
    done
    
    # Si evtest se termina, reintentar
    log_warning "evtest finalizó, reiniciando en 5 segundos..."
    sleep 5
}

# Loop principal con reintentos
while true; do
    main_loop
done
