#!/bin/bash
# ============================================================================
# MUUP - SmartMicro Radar CAN Setup & Launch
# ============================================================================
# Script para configurar interfaz CAN y lanzar el driver del radar
# 
# Uso:
#   ./setup_radar_can.sh         # Configura y lanza
#   ./setup_radar_can.sh setup   # Solo configura CAN
#   ./setup_radar_can.sh launch  # Solo lanza (asume CAN ya configurado)
# ============================================================================

set -e  # Exit on error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# CONFIGURACIÓN - MODIFICA SEGÚN TU SETUP
# ============================================================================

# Interfaz CAN (ejemplos: can0, slcan0, vcan0)
CAN_INTERFACE="can0"

# Baudrate del radar (por defecto 500000 para smartmicro)
CAN_BAUDRATE=500000

# Tipo de adaptador CAN:
# - "socketcan" : Adaptadores PEAK-CAN, Kvaser, etc. (detectados automáticamente)
# - "slcan"     : Adaptadores USB-to-CAN genéricos (requiere /dev/ttyUSBx)
CAN_ADAPTER_TYPE="slcan"

# Solo para SLCAN: puerto USB (ejemplo: /dev/ttyUSB0)
SLCAN_DEVICE="/dev/ttyUSB0"

# ============================================================================
# FUNCIONES
# ============================================================================

print_header() {
    echo -e "${BLUE}"
    echo "════════════════════════════════════════════════════════════════════"
    echo "  🎯 MUUP - SmartMicro Radar CAN Setup"
    echo "════════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ Este script necesita permisos de root para configurar CAN${NC}"
        echo -e "${YELLOW}💡 Ejecuta: sudo $0 $@${NC}"
        exit 1
    fi
}

setup_socketcan() {
    echo -e "${YELLOW}📡 Configurando SocketCAN (${CAN_INTERFACE})...${NC}"
    
    # Verificar si la interfaz existe
    if ! ip link show "$CAN_INTERFACE" &> /dev/null; then
        echo -e "${RED}❌ Interfaz $CAN_INTERFACE no encontrada${NC}"
        echo -e "${YELLOW}💡 Interfaces CAN disponibles:${NC}"
        ip link show | grep can || echo "   Ninguna interfaz CAN detectada"
        exit 1
    fi
    
    # Detener interfaz si está activa
    ip link set "$CAN_INTERFACE" down 2>/dev/null || true
    
    # Configurar baudrate y activar
    ip link set "$CAN_INTERFACE" type can bitrate "$CAN_BAUDRATE"
    ip link set "$CAN_INTERFACE" up
    
    # Aumentar buffer de transmisión (recomendado)
    ip link set "$CAN_INTERFACE" txqueuelen 4096
    
    echo -e "${GREEN}✅ SocketCAN configurado: $CAN_INTERFACE @ ${CAN_BAUDRATE} bps${NC}"
}

setup_slcan() {
    echo -e "${YELLOW}📡 Configurando SLCAN (${SLCAN_DEVICE} -> ${CAN_INTERFACE})...${NC}"
    
    # Verificar que el dispositivo USB existe
    if [[ ! -e "$SLCAN_DEVICE" ]]; then
        echo -e "${RED}❌ Dispositivo $SLCAN_DEVICE no encontrado${NC}"
        echo -e "${YELLOW}💡 Dispositivos USB disponibles:${NC}"
        ls /dev/ttyUSB* 2>/dev/null || echo "   Ningún dispositivo USB detectado"
        exit 1
    fi
    
    # Matar procesos slcand anteriores
    killall slcand 2>/dev/null || true
    
    # Detener interfaz si existe
    ip link set "$CAN_INTERFACE" down 2>/dev/null || true
    
    # Convertir baudrate a código -s de slcand
    # Mapeo: 10k=s0, 20k=s1, 50k=s2, 100k=s3, 125k=s4, 250k=s5, 500k=s6, 800k=s7, 1000k=s8
    case "$CAN_BAUDRATE" in
        10000)   SLCAN_SPEED="0" ;;
        20000)   SLCAN_SPEED="1" ;;
        50000)   SLCAN_SPEED="2" ;;
        100000)  SLCAN_SPEED="3" ;;
        125000)  SLCAN_SPEED="4" ;;
        250000)  SLCAN_SPEED="5" ;;
        500000)  SLCAN_SPEED="6" ;;
        800000)  SLCAN_SPEED="7" ;;
        1000000) SLCAN_SPEED="8" ;;
        *)
            echo -e "${RED}❌ Baudrate no soportado: $CAN_BAUDRATE${NC}"
            echo -e "${YELLOW}💡 Baudrates válidos: 10k, 20k, 50k, 100k, 125k, 250k, 500k, 800k, 1000k${NC}"
            exit 1
            ;;
    esac
    
    # Configurar SLCAN
    # -o : Open
    # -s<N> : Speed (calculado desde $CAN_BAUDRATE)
    # -t hw : Hardware flow control
    # -S 3000000 : Baudrate serial (3Mbps)
    slcand -o -s${SLCAN_SPEED} -t hw -S 3000000 "$SLCAN_DEVICE" "$CAN_INTERFACE"
    
    # Activar interfaz
    ip link set "$CAN_INTERFACE" up
    
    # Aumentar buffer
    ip link set "$CAN_INTERFACE" txqueuelen 4096
    
    echo -e "${GREEN}✅ SLCAN configurado: $SLCAN_DEVICE -> $CAN_INTERFACE @ ${CAN_BAUDRATE} bps${NC}"
}

setup_can() {
    print_header
    
    if [[ "$CAN_ADAPTER_TYPE" == "socketcan" ]]; then
        setup_socketcan
    elif [[ "$CAN_ADAPTER_TYPE" == "slcan" ]]; then
        setup_slcan
    else
        echo -e "${RED}❌ Tipo de adaptador desconocido: $CAN_ADAPTER_TYPE${NC}"
        exit 1
    fi
    
    # Verificar que la interfaz está activa
    echo ""
    echo -e "${BLUE}📊 Estado de la interfaz:${NC}"
    ip -details link show "$CAN_INTERFACE"
    
    echo ""
    echo -e "${GREEN}✅ Interfaz CAN lista para usar${NC}"
}

launch_radar() {
    echo ""
    echo -e "${YELLOW}🚀 Lanzando driver del radar...${NC}"
    echo ""
    
    # Source ROS2
    source /opt/ros/humble/setup.bash
    source /ros2_ws/install/setup.bash
    
    # Lanzar
    ros2 launch umrr_ros2_driver radar_can_muup.launch.py
}

show_info() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📋 Información de configuración:${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
    echo "  Interfaz CAN:     $CAN_INTERFACE"
    echo "  Baudrate:         $CAN_BAUDRATE bps"
    echo "  Tipo adaptador:   $CAN_ADAPTER_TYPE"
    if [[ "$CAN_ADAPTER_TYPE" == "slcan" ]]; then
        echo "  Dispositivo USB:  $SLCAN_DEVICE"
    fi
    echo ""
    echo -e "${YELLOW}💡 Comandos útiles:${NC}"
    echo "  Ver tráfico CAN:     candump $CAN_INTERFACE"
    echo "  Estadísticas:        ip -s link show $CAN_INTERFACE"
    echo "  Desactivar:          sudo ip link set $CAN_INTERFACE down"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
}

# ============================================================================
# MAIN
# ============================================================================

case "${1:-all}" in
    setup)
        check_root
        setup_can
        show_info
        ;;
    launch)
        launch_radar
        ;;
    all)
        check_root
        setup_can
        show_info
        echo ""
        read -p "🚀 ¿Lanzar driver del radar ahora? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            launch_radar
        fi
        ;;
    *)
        echo "Uso: $0 [setup|launch|all]"
        echo "  setup  - Solo configura interfaz CAN (requiere root)"
        echo "  launch - Solo lanza driver (asume CAN ya configurado)"
        echo "  all    - Configura CAN y lanza driver (default)"
        exit 1
        ;;
esac
