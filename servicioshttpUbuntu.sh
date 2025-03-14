#!/bin/bash

# Cargar scripts de funciones
source ./Funciones/validaciones.sh
source ./Funciones/ValidarSudo.sh
source ./Funciones/InstalarServHTTPubuntu.sh

# Validar que el script se ejecuta como root
ValidarSudo

# Definir colores para la salida
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
NORMAL='\033[0m'

echo "============================================="
echo "  INSTALADOR DE SERVICIOS HTTP  "
echo "============================================="

# Menú inicial
PS3="Seleccione el servicio a instalar: "
options=("Apache" "Nginx" "Tomcat" "Lighttpd" "Salir")

while true; do
    select opcion in "${options[@]}"; do
        case "$REPLY" in
            1) 
                read -p "Ingrese el puerto para Apache (1-65535): " puerto
                if validar_numero "$puerto" && ! puerto_en_uso "$puerto"; then
                    instalar_apache "$puerto"
                else
                    echo -e "${ROJO}Puerto no válido o en uso.${NORMAL}"
                fi
                break
                ;;
            2) 
                instalar_servidor "Nginx" "nginx"
                break
                ;;
            3) 
                instalar_tomcat "10.1.13" "8080"
                break
                ;;
            4) 
                instalar_servidor "Lighttpd" "lighttpd"
                break
                ;;
            5) 
                echo "Saliendo..."
                exit 0
                ;;
            *) 
                echo -e "${ROJO}Opción no válida.${NORMAL}"
                break
                ;;
        esac
    done
done
