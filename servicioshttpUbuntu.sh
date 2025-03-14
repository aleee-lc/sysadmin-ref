#!/bin/bash

source ./Funciones/ValidarSudo.sh
source ./Funciones/InstalarServHTTPubuntu.sh

echo "============================================="
echo "  INSTALADOR DE SERVICIOS HTTP  "
echo "============================================="

# Menú inicial
PS3="Seleccione el servicio a instalar: "
options=("Apache" "Nginx" "Tomcat" "Lighttpd" "Salir")

select opcion in "${options[@]}"; do
    case "$REPLY" in
        1) read -p "Ingrese el puerto para Apache (1-65535): " puerto
           validar_numero "$puerto" && ! puerto_en_uso "$puerto" && instalar_apache "$puerto" ;;
        2) instalar_servidor "Nginx" "nginx" ;;
        3) instalar_tomcat "10.1.13" "8080" ;;
        4) instalar_servidor "Lighttpd" "lighttpd" ;;
        5) echo "Saliendo..."; exit 0 ;;
        *) echo -e "${ROJO}Opción no válida.${NORMAL}" ;;
    esac
done