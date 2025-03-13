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

# Función para validar números
validar_numero() {
    local numero=$1
    if [[ $numero =~ ^[0-9]+$ ]] && [ "$numero" -ge 1 ] && [ "$numero" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Función para instalar y comprobar Apache (solo una vez)
instalar_apache() {
    local puerto=$1
    if dpkg -l | grep -q "^ii  apache2"; then
        echo -e "${VERDE}Apache2 ya está instalado.${NORMAL}"
    else
        echo -e "${AMARILLO}Instalando Apache2...${NORMAL}"
        apt update && apt install -y apache2
    fi
    
    # Eliminar líneas duplicadas de Listen en la configuración de Apache
    sed -i "/^Listen /d" /etc/apache2/ports.conf
    echo "Listen $puerto" >> /etc/apache2/ports.conf

    # Actualizar el archivo de configuración del sitio por defecto
    sed -i "s/<VirtualHost \*:80>/<VirtualHost *:$puerto>/g" /etc/apache2/sites-available/000-default.conf
    
    systemctl restart apache2
    
    if systemctl is-active --quiet apache2; then
        echo -e "${VERDE}✓ Apache2 funcionando en el puerto $puerto${NORMAL}"
    else
        echo -e "${ROJO}✗ Error al iniciar Apache2.${NORMAL}"
        systemctl status apache2 --no-pager
    fi
}

# Función para instalar Tomcat manualmente
instalar_tomcat() {
    local version=$1
    local puerto=$2
    local tomcat_home="/opt/tomcat"
    
    # Verificar si Java está instalado
    if ! command -v java &> /dev/null; then
        echo -e "${AMARILLO}Instalando Java...${NORMAL}"
        apt update && apt install -y default-jdk
    fi
    
    # Comprobar si Tomcat ya está instalado
    if [ -d "$tomcat_home" ]; then
        echo -e "${VERDE}Tomcat ya está instalado en $tomcat_home.${NORMAL}"
        read -p "¿Desea reinstalar Tomcat? (s/n): " respuesta
        if [[ "$respuesta" != "s" && "$respuesta" != "S" ]]; then
            echo -e "${AMARILLO}Omitiendo instalación de Tomcat.${NORMAL}"
            return
        fi
        
        # Detener y desinstalar Tomcat si existe
        if [ -f "$tomcat_home/bin/shutdown.sh" ]; then
            echo -e "${AMARILLO}Deteniendo Tomcat...${NORMAL}"
            $tomcat_home/bin/shutdown.sh
            sleep 2
        fi
        
        echo -e "${AMARILLO}Eliminando instalación anterior de Tomcat...${NORMAL}"
        rm -rf $tomcat_home
        
        # Eliminar servicio systemd si existe
        if [ -f "/etc/systemd/system/tomcat.service" ]; then
            systemctl disable tomcat
            rm -f /etc/systemd/system/tomcat.service
            systemctl daemon-reload
        fi
    fi
    
    # Crear directorio para Tomcat
    mkdir -p $tomcat_home
    cd /tmp
    
    # Descargar Tomcat según la versión
    local tomcat_url=""
    if [[ "$version" == "9.0.75" ]]; then
        tomcat_url="https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.75/bin/apache-tomcat-9.0.75.tar.gz"
    elif [[ "$version" == "10.1.13" ]]; then
        tomcat_url="https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.13/bin/apache-tomcat-10.1.13.tar.gz"
    else
        echo -e "${ROJO}Versión de Tomcat no soportada.${NORMAL}"
        return 1
    fi
    
    echo -e "${AMARILLO}Descargando Tomcat versión $version...${NORMAL}"
    if wget -q "$tomcat_url" -O tomcat.tar.gz; then
        echo -e "${VERDE}Descarga completada. Extrayendo archivos...${NORMAL}"
        tar xf tomcat.tar.gz -C $tomcat_home --strip-components=1
        rm tomcat.tar.gz
    else
        echo -e "${ROJO}Error al descargar Tomcat. Compruebe su conexión a Internet.${NORMAL}"
        return 1
    fi
    
    # Crear usuario tomcat
    if ! id -u tomcat &>/dev/null; then
        echo -e "${AMARILLO}Creando usuario tomcat...${NORMAL}"
        useradd -m -d $tomcat_home -U -s /bin/false tomcat
    fi
    
    # Configurar permisos
    chown -R tomcat:tomcat $tomcat_home
    chmod +x $tomcat_home/bin/*.sh
    
    # Configurar puerto
    echo -e "${AMARILLO}Configurando Tomcat para usar el puerto $puerto...${NORMAL}"
    sed -i "s/port=\"8080\"/port=\"$puerto\"/" $tomcat_home/conf/server.xml
    
    # Crear servicio systemd
    echo -e "${AMARILLO}Creando servicio systemd para Tomcat...${NORMAL}"
    cat > /etc/systemd/system/tomcat.service << EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=tomcat
Group=tomcat
Environment="JAVA_HOME=/usr/lib/jvm/default-java"
Environment="CATALINA_HOME=$tomcat_home"
Environment="CATALINA_BASE=$tomcat_home"
Environment="CATALINA_PID=$tomcat_home/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M"

ExecStart=$tomcat_home/bin/startup.sh
ExecStop=$tomcat_home/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOF
    
    # Recargar systemd y habilitar servicio
    systemctl daemon-reload
    systemctl enable tomcat
    systemctl start tomcat
    
    sleep 3 # Esperar a que Tomcat se inicie
    
    if systemctl is-active --quiet tomcat; then
        echo -e "${VERDE}✓ Tomcat $version instalado y funcionando en el puerto $puerto${NORMAL}"
        echo -e "${VERDE}Puede acceder a Tomcat en: http://localhost:$puerto${NORMAL}"
        echo -e "${VERDE}El directorio de instalación es: $tomcat_home${NORMAL}"
    else
        echo -e "${ROJO}✗ Error al iniciar Tomcat. Verifique el log:${NORMAL}"
        cat $tomcat_home/logs/catalina.out | tail -n 20
        systemctl status tomcat --no-pager
    fi
}

# Función para instalar y configurar servicios adicionales
instalar_servicio() {
    local servicio=$1
    local paquete=$2
    
    # Caso especial para Tomcat (instalación manual)
    if [ "$servicio" = "Tomcat" ]; then
        echo -e "${AMARILLO}Obteniendo versiones de Tomcat...${NORMAL}"
        versiones=( "9.0.75" "10.1.13" )
        
        echo -e "${VERDE}Versiones de Tomcat disponibles:${NORMAL}"
        select version in "${versiones[@]}"; do
            if [[ -n "$version" ]]; then
                read -p "Ingrese el puerto para Tomcat (1-65535): " puerto
                if ! validar_numero "$puerto"; then
                    echo -e "${ROJO}El puerto ingresado no es válido.${NORMAL}"
                    return
                fi
                
                # Verificar si el puerto está en uso
                if netstat -tuln | grep -q ":$puerto "; then
                    echo -e "${ROJO}El puerto $puerto ya está en uso. Por favor elija otro puerto.${NORMAL}"
                    return
                fi
                
                echo -e "${AMARILLO}Instalando Tomcat versión $version en el puerto $puerto...${NORMAL}"
                instalar_tomcat "$version" "$puerto"
                break
            else
                echo -e "${ROJO}Selección no válida.${NORMAL}"
            fi
        done
        return
    fi
    
    # Para otros servicios (Nginx, Lighttpd)
    # Verificar si el paquete está instalado
    if dpkg -l | grep -q "^ii  $paquete"; then
        echo -e "${VERDE}$servicio ya está instalado.${NORMAL}"
        read -p "¿Desea reinstalar $servicio? (s/n): " respuesta
        if [[ "$respuesta" != "s" && "$respuesta" != "S" ]]; then
            echo -e "${AMARILLO}Omitiendo instalación de $servicio.${NORMAL}"
            return
        fi
        echo -e "${AMARILLO}Desinstalando $servicio...${NORMAL}"
        systemctl stop "$paquete" 2>/dev/null
        apt remove --purge -y "$paquete"
    fi

    echo -e "${AMARILLO}Obteniendo versiones de $servicio...${NORMAL}"
    
    case "$servicio" in
        "Nginx") 
            versiones=( "1.22.1" "1.24.0" )
            ;;
        "Lighttpd") 
            versiones=( "1.4.65" "1.4.70" )
            ;;
    esac
    
    echo -e "${VERDE}Versiones de $servicio disponibles:${NORMAL}"
    select version in "${versiones[@]}"; do
        if [[ -n "$version" ]]; then
            read -p "Ingrese el puerto para $servicio (1-65535): " puerto
            if ! validar_numero "$puerto"; then
                echo -e "${ROJO}El puerto ingresado no es válido.${NORMAL}"
                return
            fi
            
            # Verificar si el puerto está en uso
            if netstat -tuln | grep -q ":$puerto "; then
                echo -e "${ROJO}El puerto $puerto ya está en uso. Por favor elija otro puerto.${NORMAL}"
                return
            fi
            
            echo -e "${AMARILLO}Instalando $servicio versión $version en el puerto $puerto...${NORMAL}"
            apt update && apt install -y "$paquete"
            
            if dpkg -l | grep -q "^ii  $paquete"; then
                echo -e "${VERDE}✓ $servicio instalado correctamente.${NORMAL}"
            else
                echo -e "${ROJO}✗ Error al instalar $servicio.${NORMAL}"
                return
            fi
            
            # Detener el servicio antes de configurar
            systemctl stop "$paquete" 2>/dev/null
            
            # Configurar el puerto según el servicio específico
            case "$servicio" in
                "Nginx")
                    # Configuración completa de nginx para usar el puerto especificado
                    cat > /etc/nginx/sites-available/default << EOF
server {
    listen $puerto default_server;
    listen [::]:$puerto default_server;
    
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
                    # Asegurarse de que no haya configuración de puerto en nginx.conf
                    sed -i '/listen/d' /etc/nginx/nginx.conf
                    ;;
                "Lighttpd")
                    sed -i "s/server\.port[[:space:]]=[[:space:]][0-9]*/server.port = $puerto/" /etc/lighttpd/lighttpd.conf
                    ;;
            esac
            
            # Reiniciar el servicio
            systemctl restart "$paquete"
            sleep 3  # Pausa para permitir que el servicio se inicie completamente
            
            if systemctl is-active --quiet "$paquete"; then
                echo -e "${VERDE}✓ $servicio funcionando en el puerto $puerto${NORMAL}"
                echo -e "${VERDE}Puede acceder al servicio en: http://localhost:$puerto${NORMAL}"
            else
                echo -e "${ROJO}✗ Error al iniciar $servicio. Verifique el log:${NORMAL}"
                systemctl status "$paquete" --no-pager
                
                # Información adicional de diagnóstico
                if [ "$servicio" = "Nginx" ]; then
                    echo -e "${AMARILLO}Verificando configuración de Nginx:${NORMAL}"
                    nginx -t
                    echo -e "${AMARILLO}Puertos en uso:${NORMAL}"
                    netstat -tulpn | grep nginx
                fi
            fi
            break
        else
            echo -e "${ROJO}Selección no válida.${NORMAL}"
        fi
    done
}

# Verificar que netstat esté instalado
if ! command -v netstat &> /dev/null; then
    echo -e "${AMARILLO}Instalando net-tools para verificar puertos...${NORMAL}"
    apt update && apt install -y net-tools
fi

# Verificar que wget esté instalado
if ! command -v wget &> /dev/null; then
    echo -e "${AMARILLO}Instalando wget para descargas...${NORMAL}"
    apt update && apt install -y wget
fi

# Solicitar el puerto de Apache antes de la instalación
read -p "Ingrese el puerto para Apache2 (1-65535): " puerto
if ! validar_numero "$puerto"; then
    echo -e "${ROJO}El puerto ingresado no es válido.${NORMAL}"
    exit 1
fi

# Verificar si el puerto está en uso
if netstat -tuln | grep -q ":$puerto "; then
    echo -e "${ROJO}El puerto $puerto ya está en uso. Por favor elija otro puerto.${NORMAL}"
    exit 1
fi

instalar_apache "$puerto"

# Menú principal
while true; do
    clear
    echo -e "${VERDE}=== Instalación de Servicios HTTP en Ubuntu ===${NORMAL}"
    echo "1.- Nginx"
    echo "2.- Tomcat"
    echo "3.- Lighttpd"
    echo "4.- Salir"
    read -p "Seleccione el servicio adicional (1-4): " opcion
    
    case "$opcion" in
        1) instalar_servicio "Nginx" "nginx" ;;
        2) instalar_servicio "Tomcat" "tomcat9" ;;
        3) instalar_servicio "Lighttpd" "lighttpd" ;;
        4) echo "Saliendo..."; exit 0 ;;
        *) echo -e "${ROJO}Opción no válida.${NORMAL}" ;;
    esac
    read -p "Presione Enter para continuar..."
done