# 📺 Smart TV Automation - Raspberry Pi

Automatización de Smart TV para fácil acceso a aplicaciones favoritas mediante control remoto IR. Sistema basado en ADB (Android Debug Bridge) y escucha de eventos de infrarrojo.

## 📋 Tabla de Contenidos

- [Características](#características)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Configuración](#configuración)
- [Uso](#uso)
- [Troubleshooting](#troubleshooting)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Logs](#logs)
- [Desarrollo](#desarrollo)

---

## ✨ Características

- ✅ **Conexión ADB automática** con reintentos inteligentes
- ✅ **Configuración automática de protocolo IR** (NEC/NECx)
- ✅ **Escucha de controles remotos** en tiempo real
- ✅ **Navegación automática** a aplicaciones (Ej: Magis)
- ✅ **Detección de pop-ups** automática
- ✅ **Logs centralizados** con rotación automática
- ✅ **Servicios systemd** con dependencias correctas
- ✅ **Tolerancia a fallos** con reintentos y timeouts
- ✅ **Fácil diagnóstico** con script de troubleshooting

---

## 📦 Requisitos

### Hardware
- Raspberry Pi (cualquier versión, recomendado Pi 4)
- Smart TV con ADB habilitado
- Control remoto IR compatible con protocolo NEC
- Receptor IR conectado a GPIO

### Software
- Raspberry Pi OS (Debian-based)
- Python 3 (opcional, para scripts avanzados)
- Herramientas necesarias:
  - `adb` (Android Debug Bridge)
  - `ir-keytable` (Linux IR tools)
  - `evtest` (input device tester)
  - `systemd` (para servicios)

### Instalación de dependencias

```bash
# Actualizar sistema
sudo apt update
sudo apt upgrade -y

# Instalar ADB
sudo apt install -y android-tools-adb android-tools-fastboot

# Instalar IR tools
sudo apt install -y ir-keytable

# Instalar evtest (para eventos de input)
sudo apt install -y evtest

# Instalar utilidades útiles
sudo apt install -y tmux curl wget git
```

---

## 🚀 Instalación

### Paso 1: Clonar el repositorio

```bash
# Opción A: Con git
git clone https://github.com/royerio/smarttv-automation.git
cd smarttv-automation

# Opción B: Descargar manualmente
# Descargar el zip y extraerlo
```

### Paso 2: Ejecutar el instalador

```bash
# Dar permisos de ejecución
chmod +x bin/install.sh

# Ejecutar como root
sudo bash bin/install.sh
```

El instalador hará automáticamente:
- ✅ Copiar scripts a `/usr/local/bin/smarttv/`
- ✅ Copiar configuración a `/etc/smarttv-automation/`
- ✅ Instalar servicios systemd
- ✅ Recargar daemon systemd
- ✅ Crear directorios de logs
- ✅ Habilitar servicios para inicio automático

### Paso 3: Verificar instalación

```bash
# Ejecutar diagnóstico
sudo bash bin/diagnose.sh
```

Debería mostrar algo como:
```
✓ adb instalado
✓ ir-keytable instalado
✓ evtest instalado
✓ smarttv.conf existe
✓ adb-autoreconnect.service activo
✓ ir-protocol.service activo
✓ ir-listener.service activo
```

---

## ⚙️ Configuración

### Archivo de Configuración Principal

El archivo `/etc/smarttv-automation/smarttv.conf` contiene todas las variables de configuración:

```bash
# ADB - Dirección IP y puerto del TV
ADB_TARGET="192.168.101.50:5555"
ADB_CHECK_INTERVAL=5              # Segundos entre checks

# IR - Dispositivo y protocolo
IR_DEVICE="/dev/input/event0"
IR_PROTOCOL="nec,necx"
IR_RETRIES=5

# LOGGING
LOG_DIR="/var/log/smarttv-automation"
LOG_LEVEL="INFO"                  # DEBUG, INFO, WARNING, ERROR
MAGIS_LOG="/var/log/magis.log"
MAX_LOG_SIZE=10485760             # 10MB
LOG_RETENTION_DAYS=7

# APPS
MAGIS_APP="com.android.mgstv"     # Package de la app
```

#### Cambiar la IP del TV

Si tu TV tiene otra IP, edita el archivo:

```bash
sudo nano /etc/smarttv-automation/smarttv.conf
```

Cambia:
```bash
ADB_TARGET="TU_IP_AQUI:5555"
```

Luego recarga los servicios:
```bash
sudo systemctl daemon-reload
sudo systemctl restart adb-autoreconnect.service
```

#### Ajustar nivel de logging

Para más verbosidad (útil para debugging):
```bash
sudo sed -i 's/LOG_LEVEL="INFO"/LOG_LEVEL="DEBUG"/' \
  /etc/smarttv-automation/smarttv.conf
```

---

## 💻 Uso

### Comandos Básicos

#### Ver estado de servicios

```bash
# Ver todos los servicios
systemctl status adb-autoreconnect.service
systemctl status ir-protocol.service
systemctl status ir-listener.service

# Resumen rápido
systemctl is-active adb-autoreconnect.service && echo "✓ ADB OK" || echo "✗ ADB FAILED"
```

#### Ver logs en tiempo real

```bash
# ADB auto-reconnect
sudo journalctl -u adb-autoreconnect.service -f

# IR Protocol configuration
sudo journalctl -u ir-protocol.service -f

# IR Listener
sudo journalctl -u ir-listener.service -f

# Todos los servicios
sudo journalctl -u smarttv-automation -f
```

#### Detener/Iniciar servicios

```bash
# Detener todo
sudo systemctl stop adb-autoreconnect.service
sudo systemctl stop ir-protocol.service
sudo systemctl stop ir-listener.service

# Iniciar todo
sudo systemctl start adb-autoreconnect.service
sudo systemctl start ir-protocol.service
sudo systemctl start ir-listener.service

# Reiniciar todo
sudo systemctl restart adb-autoreconnect.service
sudo systemctl restart ir-protocol.service
sudo systemctl restart ir-listener.service
```

#### Probar manualmente

```bash
# Conectar ADB manualmente
adb connect 192.168.101.50:5555

# Ver dispositivos conectados
adb devices

# Ejecutar magis.sh manualmente
bash /home/royerio/magis.sh

# Escuchar eventos IR (presiona botones en el control)
sudo evtest /dev/input/event0
```

### Flujo de Funcionamiento

```
┌─────────────────────────────────────────────────────────────────┐
│                    SMART TV AUTOMATION FLOW                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. adb-autoreconnect.service INICIA                            │
│     ├─ Intenta conectar a TV por ADB                            │
│     ├─ Si FALLA: reintentar cada 5 segundos                    │
│     └─ Si OK: pasar a paso 2                                    │
│                                                                   │
│  2. ir-protocol.service INICIA                                  │
│     ├─ Esperar a que dispositivo IR esté listo                 │
│     ├─ Configurar protocolo NEC/NECx (5 reintentos)            │
│     └─ RemainAfterExit=yes (se mantiene "activo")              │
│                                                                   │
│  3. ir-listener.service INICIA                                  │
│     ├─ Esperar ADB + IR listos                                 │
│     ├─ Escuchar eventos de /dev/input/event0                  │
│     ├─ Si botón OK presionado → ejecutar magis.sh             │
│     └─ Reintentar si evtest cuelga (timeout 1 hora)            │
│                                                                   │
│  4. Usuario presiona botón OK del control remoto               │
│     ├─ Evento detectado en /dev/input/event0                  │
│     ├─ ir-listener.sh identifica KEY_OK                       │
│     └─ Ejecuta magis.sh                                         │
│                                                                   │
│  5. magis.sh EJECUTA                                            │
│     ├─ Ir a home (keyevent 3)                                  │
│     ├─ Lanzar app Magis                                        │
│     ├─ Esperar 15 segundos                                     │
│     ├─ Detectar pop-ups                                        │
│     ├─ Navegar a lista de favoritos                            │
│     └─ Registrar en /var/log/magis.log                         │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔍 Troubleshooting

### ADB no conecta

```bash
# Verificar que TV está en red
ping 192.168.101.50

# Verificar que ADB está disponible
which adb

# Conectar manualmente
adb connect 192.168.101.50:5555

# Ver dispositivos
adb devices

# Ver logs de ADB
sudo journalctl -u adb-autoreconnect.service -n 20
```

**Solución**: Asegúrate que:
- TV está en la misma red que Raspberry Pi
- ADB está habilitado en TV (Settings → Developer Options → USB Debugging)
- Firewall no bloquea puerto 5555

### Protocolo IR no configura

```bash
# Verificar que ir-keytable está instalado
which ir-keytable

# Ejecutar diagnóstico
sudo bash bin/diagnose.sh

# Ver logs
sudo journalctl -u ir-protocol.service -f
```

**Solución**: 
- Verifica que el receptor IR está conectado
- Comprueba que `/dev/input/event0` existe
- Intenta configurar manualmente: `sudo ir-keytable -s rc0 -p nec,necx`

### Listener no detecta pulsaciones

```bash
# Probar evtest directamente
sudo evtest /dev/input/event0

# Presiona botones en el control remoto
# Deberías ver eventos como: "MSC_SCAN   7f10"
```

**Solución**:
- Verifica que el código de botón es correcto (por defecto: `7f10`)
- Si es diferente, edita `/usr/local/bin/smarttv/ir-listener.sh`
- Cambia la línea: `if echo "$line" | grep -qi "MSC_SCAN.*7f10\|KEY_OK"`

### magis.sh no ejecuta

```bash
# Ejecutar manualmente para ver errores
bash /usr/local/bin/smarttv/magis.sh

# Ver logs de magis
tail -f /var/log/magis.log
```

**Solución**:
- Verifica que ADB está conectado: `adb devices`
- Verifica que app Magis está instalada en TV
- Verifica que el script tiene permisos de ejecución: `ls -la /usr/local/bin/smarttv/magis.sh`

### Logs ocupan demasiado espacio

```bash
# Ver uso actual de logs
sudo journalctl --disk-usage

# Limpiar logs antiguos
sudo journalctl --vacuum-time=7d

# Rotación manual
sudo journalctl --rotate
```

### Script cuelga permanentemente

```bash
# Ver procesos en ejecución
ps aux | grep -E "adb|ir|evtest"

# Matar proceso específico
sudo pkill -f ir-listener.sh
sudo pkill -f adb-autoreconnect.sh

# Reiniciar servicios
sudo systemctl restart ir-listener.service
```

---

## 📁 Estructura del Proyecto

```
smarttv-automation/
├── README.md                           # Este archivo
├── config/
│   └── smarttv.conf                   # Configuración centralizada
├── scripts/
│   ├── adb-autoreconnect.sh          # Reconexión automática ADB
│   ├── ir-protocol-check.sh          # Configurar protocolo IR
│   ├── ir-listener.sh                # Escuchar eventos IR
│   ├── magis.sh                      # Navegar a Magis
│   └── common-functions.sh           # Funciones reutilizables
├── systemd/
│   ├── adb-autoreconnect.service    # Servicio systemd
│   ├── ir-protocol.service          # Servicio systemd
│   └── ir-listener.service          # Servicio systemd
├── bin/
│   ├── install.sh                    # Script de instalación
│   ├── uninstall.sh                 # Script de desinstalación
│   └── diagnose.sh                  # Diagnóstico automático
└── docs/
    ├── INSTALLATION.md              # Guía detallada de instalación
    ├── DEVELOPMENT.md               # Guía para desarrolladores
    └── TROUBLESHOOTING.md           # Solución de problemas
```

### Directorios instalados

Después de ejecutar `install.sh`:

```
/usr/local/bin/smarttv/               # Scripts ejecutables
├── adb-autoreconnect.sh
├── ir-protocol-check.sh
├── ir-listener.sh
├── magis.sh
└── common-functions.sh

/etc/smarttv-automation/              # Configuración
└── smarttv.conf

/etc/systemd/system/                  # Servicios
├── adb-autoreconnect.service
├── ir-protocol.service
└── ir-listener.service

/var/log/smarttv-automation/          # Logs
├── smarttv-automation.log
└── magis.log
```

---

## 📊 Logs

### Ver logs recientes

```bash
# Últimas 50 líneas
sudo journalctl -u adb-autoreconnect.service -n 50

# En tiempo real
sudo journalctl -u adb-autoreconnect.service -f

# Últimas 2 horas
sudo journalctl -u adb-autoreconnect.service --since "2 hours ago"

# Desde una fecha específica
sudo journalctl -u adb-autoreconnect.service --since "2024-01-28 10:00:00"
```

### Niveles de log

El archivo de configuración tiene un nivel `LOG_LEVEL` que controla verbosidad:

- `DEBUG`: Todo incluyendo comandos ejecutados
- `INFO`: Eventos importantes (default)
- `WARNING`: Solo advertencias
- `ERROR`: Solo errores

Cambiar nivel:

```bash
sudo nano /etc/smarttv-automation/smarttv.conf
# Edita: LOG_LEVEL="DEBUG"
sudo systemctl restart adb-autoreconnect.service
```

### Limpiar logs

```bash
# Borrar logs de journalctl
sudo journalctl --vacuum-time=1s

# Borrar logs de archivos específicos
sudo rm /var/log/smarttv-automation/*
sudo rm /var/log/magis.log
```

---

## 🛠️ Desarrollo

### Requisitos para desarrollo

```bash
# Instalar herramientas de desarrollo
sudo apt install -y shellcheck   # Linter para bash
sudo apt install -y bats         # Testing framework
```

### Ejecutar linter

```bash
# Verificar sintaxis de scripts
shellcheck scripts/*.sh

# Verificar formato
shfmt -i 4 -d scripts/*.sh
```

### Agregar nuevos scripts

1. Crear script en `scripts/`
2. Sourced `common-functions.sh` al inicio:
   ```bash
   source /etc/smarttv-automation/smarttv.conf
   source "$COMMON_FUNCTIONS"
   ```
3. Usar funciones de logging:
   ```bash
   log_info "Mensaje"
   log_error "Error"
   log_debug "Debug"
   ```
4. Agregar servicio systemd si es necesario
5. Actualizar `README.md`

### Modificar comportamiento de magis.sh

El script `magis.sh` realiza estas acciones:

```bash
keyevent 3    # Ir a home
keyevent 22   # Navegar derecha
keyevent 20   # Navegar abajo
keyevent 23   # OK/Select
keyevent 4    # Back (para cerrar pop-ups)
```

Referencia de keycodes: https://developer.android.com/reference/android/view/KeyEvent

---

## 📝 Licencia

Este proyecto es de uso personal. Siéntete libre de adaptarlo a tus necesidades.

## 👤 Autor

Creado por **royerio** para automatización de Smart TV casera.

---

## 🤝 Contribuciones

¿Mejoras? ¿Encontraste un bug?

1. Abre un issue describiendo el problema
2. Haz un pull request con la solución
3. Asegúrate que `shellcheck` pasa

---

## ❓ Preguntas Frecuentes

**P: ¿Puedo agregar más aplicaciones?**
A: Sí, copia `magis.sh` y adapta los keycodes según la app.

**P: ¿Funciona con otras marcas de TV?**
A: Si soportan ADB sí. Quizás necesites ajustar los keycodes.

**P: ¿Puedo usar un control remoto diferente?**
A: Sí, siempre que sea compatible con Linux IR. Ajusta el código de botón en `ir-listener.sh`.

**P: ¿Cómo actualizo los scripts?**
A: Simplemente edita los archivos en `/usr/local/bin/smarttv/` y reinicia el servicio.

**P: ¿Puedo ejecutar esto en otras Raspberry Pi?**
A: Sí, cualquier Raspberry Pi con Raspberry Pi OS funciona.

---

**Última actualización**: 2026-01-28  
**Versión**: 1.0.0
