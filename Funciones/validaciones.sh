#!/bin/bash

# Verificar si el script se ejecuta como root
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script necesita ejecutarse como root. Ejecute con: sudo bash $0"
    exit 1
fi

# Colores para la visualización
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
NORMAL='\033[0m'

# Función para validar números (puertos)
validar_numero() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

# Función para verificar si un puerto está en uso
puerto_en_uso() {
    ss -tuln | grep -q ":$1 "
}