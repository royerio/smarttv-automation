#!/bin/bash
# common-functions.sh
# Funciones reutilizables para todos los scripts

# Cargar configuración
load_config() {
    local config_file="${1:-/etc/smarttv-automation/smarttv.conf}"
    
    if [[ ! -f "$config_file" ]]; then
        echo "ERROR: Archivo de configuración no encontrado: $config_file" >&2
        return 1
    fi
    
    source "$config_file"
    return 0
}

# Logging con niveles
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Crear directorio de logs si no existe
    mkdir -p "$LOG_DIR"
    
    local log_file="$LOG_DIR/smarttv-automation.log"
    
    # Determinar si loguear según LOG_LEVEL
    case "$LOG_LEVEL" in
        DEBUG)
            echo "[$timestamp] [$level] $message" | tee -a "$log_file"
            ;;
        INFO)
            [[ "$level" != "DEBUG" ]] && echo "[$timestamp] [$level] $message" | tee -a "$log_file"
            ;;
        WARNING)
            [[ "$level" =~ (WARNING|ERROR) ]] && echo "[$timestamp] [$level] $message" | tee -a "$log_file"
            ;;
        ERROR)
            [[ "$level" == "ERROR" ]] && echo "[$timestamp] [$level] $message" | tee -a "$log_file"
            ;;
    esac
}

# Alias para facilitar logging
log_info() { log "INFO" "$@"; }
log_error() { log "ERROR" "$@"; }
log_debug() { log "DEBUG" "$@"; }
log_warning() { log "WARNING" "$@"; }

# Validar que comando existe y es ejecutable
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ejecutar comando con validación
run_command() {
    local cmd="$1"
    local error_msg="${2:-Comando falló: $cmd}"
    
    log_debug "Ejecutando: $cmd"
    
    if ! output=$($cmd 2>&1); then
        log_error "$error_msg"
        log_debug "Output: $output"
        return 1
    fi
    
    return 0
}

# Verificar dependencias
check_dependencies() {
    local deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Dependencias faltantes: ${missing[*]}"
        return 1
    fi
    
    log_debug "Todas las dependencias verificadas"
    return 0
}

# Ejecutar con timeout
run_with_timeout() {
    local timeout=$1
    shift
    local cmd="$@"
    
    log_debug "Ejecutando con timeout de ${timeout}s: $cmd"
    
    timeout "$timeout" bash -c "$cmd"
    local exit_code=$?
    
    if [[ $exit_code -eq 124 ]]; then
        log_error "Comando excedió timeout de ${timeout}s: $cmd"
        return 1
    fi
    
    return $exit_code
}

# Rotar logs si son muy grandes
rotate_logs() {
    local log_file="$1"
    local max_size="${2:-$MAX_LOG_SIZE}"
    
    if [[ -f "$log_file" ]]; then
        local file_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null)
        
        if [[ $file_size -gt $max_size ]]; then
            local backup="${log_file}.$(date '+%Y%m%d-%H%M%S')"
            mv "$log_file" "$backup"
            log_info "Log rotado: $log_file -> $backup"
            
            # Limpiar logs antiguos
            find "$(dirname "$log_file")" -name "$(basename "$log_file").*" -mtime +$LOG_RETENTION_DAYS -delete
        fi
    fi
}

# Esperar a que ADB esté disponible
wait_for_adb() {
    local target="$1"
    local timeout="${2:-$ADB_CONNECT_TIMEOUT}"
    local start_time=$(date +%s)
    
    while true; do
        if $ADB_COMMAND devices | grep -q "$target"; then
            log_info "ADB disponible: $target"
            return 0
        fi
        
        local elapsed=$(($(date +%s) - start_time))
        if [[ $elapsed -gt $timeout ]]; then
            log_error "Timeout esperando ADB: $target (${timeout}s)"
            return 1
        fi
        
        sleep 1
    done
}

# Esperar a que dispositivo IR esté listo
wait_for_ir_device() {
    local device="$1"
    local timeout="${2:-30}"
    local start_time=$(date +%s)
    
    while true; do
        if [[ -e "$device" ]]; then
            log_info "Dispositivo IR disponible: $device"
            return 0
        fi
        
        local elapsed=$(($(date +%s) - start_time))
        if [[ $elapsed -gt $timeout ]]; then
            log_error "Timeout esperando dispositivo IR: $device (${timeout}s)"
            return 1
        fi
        
        sleep 1
    done
}

# Verificar que se corre con permisos suficientes
require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script requiere permisos de root"
        return 1
    fi
    return 0
}

# Salir de forma limpia
cleanup() {
    local exit_code=$?
    log_debug "Script terminando con código: $exit_code"
    exit $exit_code
}

# Exportar todas las funciones
export -f log log_info log_error log_debug log_warning
export -f command_exists run_command check_dependencies run_with_timeout
export -f rotate_logs wait_for_adb wait_for_ir_device require_root cleanup