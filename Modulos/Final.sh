#!/bin/bash

# ================== VARIABLES DE COLOR ==================
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
NORMAL='\033[0m'

# ================== FUNCIONES AUXILIARES ==================
# Verificar si el script se ejecuta como root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${ROJO}Este script necesita ejecutarse como root. Use: sudo bash $0${NORMAL}"
    exit 1
fi

# Función para validar números (puertos)
validar_numero() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

# Función para verificar si un puerto está en uso
puerto_en_uso() {
    ss -tuln | grep -q ":$1 "
}

# ================== FUNCIONES DE INSTALACIÓN ==================

# 📌 **Instalar y configurar Apache**
instalar_apache() {
    local puerto=$1

    if ! dpkg -l | grep -q "^ii  apache2"; then
        echo -e "${AMARILLO}Instalando Apache2...${NORMAL}"
        apt update && apt install -y apache2
    fi

    echo -e "${AMARILLO}Configurando Apache en el puerto $puerto...${NORMAL}"
    
    # Eliminar todas las líneas Listen y añadir la nueva
    sed -i '/^Listen /d' /etc/apache2/ports.conf
    echo "Listen $puerto" >> /etc/apache2/ports.conf

    # Modificar VirtualHost para el nuevo puerto
    sed -i "s|<VirtualHost \*:.*>|<VirtualHost *:$puerto>|g" /etc/apache2/sites-available/000-default.conf

    systemctl restart apache2

    if systemctl is-active --quiet apache2; then
        echo -e "${VERDE}✓ Apache2 funcionando en el puerto $puerto${NORMAL}"
    else
        echo -e "${ROJO}✗ Error al iniciar Apache2.${NORMAL}"
        systemctl status apache2 --no-pager
    fi
}

# 📌 **Instalar y configurar Tomcat**
instalar_tomcat() {
    local version=$1
    local puerto=$2
    local tomcat_home="/opt/tomcat"

    if [ -d "$tomcat_home" ]; then
        echo -e "${VERDE}Tomcat ya está instalado en $tomcat_home.${NORMAL}"
        read -p "¿Desea reinstalar Tomcat? (s/n): " respuesta
        [[ "$respuesta" != "s" && "$respuesta" != "S" ]] && return
        systemctl stop tomcat 2>/dev/null
        rm -rf "$tomcat_home" /etc/systemd/system/tomcat.service
        systemctl daemon-reload
    fi

    mkdir -p "$tomcat_home" && cd /tmp
    local tomcat_url="https://archive.apache.org/dist/tomcat/tomcat-${version:0:1}/v$version/bin/apache-tomcat-$version.tar.gz"

    if wget -q "$tomcat_url" -O tomcat.tar.gz; then
        tar xf tomcat.tar.gz -C "$tomcat_home" --strip-components=1
        rm tomcat.tar.gz
    else
        echo -e "${ROJO}Error al descargar Tomcat.${NORMAL}"
        return 1
    fi

    id -u tomcat &>/dev/null || useradd -m -d "$tomcat_home" -U -s /bin/false tomcat
    chown -R tomcat:tomcat "$tomcat_home"
    chmod +x "$tomcat_home/bin/"*.sh

    echo -e "${AMARILLO}Configurando Tomcat en el puerto $puerto...${NORMAL}"
    
    # Modificar solo la PRIMERA aparición de `port="8080"`
    sed -i '0,/<Connector port="8080"/s//<Connector port="'"$puerto"'"/' "$tomcat_home/conf/server.xml"

    systemctl daemon-reload
    systemctl enable tomcat
    systemctl start tomcat

    if systemctl is-active --quiet tomcat; then
        echo -e "${VERDE}✓ Tomcat $version funcionando en el puerto $puerto${NORMAL}"
    else
        echo -e "${ROJO}✗ Error al iniciar Tomcat.${NORMAL}"
        tail -n 20 "$tomcat_home/logs/catalina.out"
        systemctl status tomcat --no-pager
    fi
}

# 📌 **Instalar Nginx o Lighttpd**
instalar_servidor() {
    local servicio=$1
    local paquete=$2

    if ! dpkg -l | grep -q "^ii  $paquete"; then
        echo -e "${AMARILLO}Instalando $servicio...${NORMAL}"
        apt update && apt install -y "$paquete"
    fi

    read -p "Ingrese el puerto para $servicio (1-65535): " puerto
    validar_numero "$puerto" || { echo -e "${ROJO}Puerto inválido.${NORMAL}"; return; }
    puerto_en_uso "$puerto" && { echo -e "${ROJO}Puerto en uso.${NORMAL}"; return; }

    echo -e "${AMARILLO}Configurando $servicio en el puerto $puerto...${NORMAL}"

    case "$servicio" in
        "Nginx")
            sed -i "s|listen 80;|listen $puerto;|" /etc/nginx/sites-available/default
            systemctl restart nginx
            ;;
        "Lighttpd")
            sed -i "s|server.port[[:space:]]*=[[:space:]]*[0-9]*|server.port = $puerto|" /etc/lighttpd/lighttpd.conf
            systemctl restart lighttpd
            ;;
    esac

    if systemctl is-active --quiet "$paquete"; then
        echo -e "${VERDE}✓ $servicio funcionando en el puerto $puerto${NORMAL}"
    else
        echo -e "${ROJO}✗ Error al iniciar $servicio.${NORMAL}"
        systemctl status "$paquete" --no-pager
    fi
}

# ================== MENÚ PRINCIPAL ==================
PS3="Seleccione el servicio a instalar: "
options=("Apache" "Nginx" "Tomcat" "Lighttpd" "Salir")

while true; do
    select opcion in "${options[@]}"; do
        case "$REPLY" in
            1) read -p "Ingrese el puerto para Apache: " puerto
               validar_numero "$puerto" && ! puerto_en_uso "$puerto" && instalar_apache "$puerto"; break ;;
            2) instalar_servidor "Nginx" "nginx"; break ;;
            3) instalar_tomcat "10.1.13" "8080"; break ;;
            4) instalar_servidor "Lighttpd" "lighttpd"; break ;;
            5) echo "Saliendo..."; exit 0 ;;
            *) echo -e "${ROJO}Opción no válida.${NORMAL}"; break ;;
        esac
    done
done
