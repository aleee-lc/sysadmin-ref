#!/bin/bash

source ./Funciones/ValidarSudo.sh
source ./Funciones/InstalarServHTTPubuntu.sh

echo "============================================="
echo "  INSTALADOR DE SERVICIOS HTTP  "
echo "============================================="

echo "Seleccione un servicio para instalar:"
echo "1.- Apache"
echo "2.- Tomcat"
echo "3.- Nginx"
read -p "Opción: " opcion

case $opcion in 
    1) instalar_apache ;;
    2) instalar_tomcat ;;
    3) instalar_nginx ;;
    *) echo "Opción inválida." ;;
esac
