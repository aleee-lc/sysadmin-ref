#!/bin/bash

# Funcion para obtener versiones de Apache
obtener_versiones_apache() {
    curl -s https://downloads.apache.org/httpd/ | grep -Eo 'httpd-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' | \
    sed 's/httpd-//;s/.tar.gz//' | sort -V | tail -5
}

# Funcion para obtener versiones de Tomcat
obtener_versiones_tomcat() {
    curl -s https://downloads.apache.org/tomcat/tomcat-10/ | grep -Eo 'v10\.[0-9]+\.[0-9]+' | sort -V | tail -5
}

# Funcion para capturar el puerto
capturar_puerto(){
    while true; do
        read -p "Ingrese el puerto en el que desea configurar el servicio (1024-65535): " puerto
        if [[ ! "$puerto" =~ ^[0-9]+$ ]] || [ "$puerto" -lt 1024 ] || [ "$puerto" -gt 65535 ]; then
            echo "¡Puerto inválido! Ingrese otro puerto nuevamente."
        else
            break
        fi
    done
}

# Funcion para instalar Apache
instalar_apache(){
    echo "Buscando versiones disponibles de Apache..."
    versiones=$(obtener_versiones_apache)
    echo "Versiones disponibles:"
    echo "$versiones"
    read -p "Elija la versión de Apache que desea instalar: " version

    echo "Instalando Apache $version..."
    apt update && apt install -y apache2

    capturar_puerto
    sed -i "s/Listen 80/Listen $puerto/" /etc/apache2/ports.conf
    systemctl restart apache2

    echo " Apache versión $version instalado correctamente en el puerto $puerto."
}

# Funcion para instalar Nginx
instalar_nginx(){
    apt update && apt install -y nginx
    capturar_puerto
    sed -i "s/listen 80;/listen $puerto;/" /etc/nginx/sites-available/default
    systemctl restart nginx
    echo "Nginx instalado correctamente en el puerto $puerto."
}

# Funcion para instalar Tomcat
instalar_tomcat(){
    echo "Buscando versiones disponibles de Tomcat..."
    versiones=$(obtener_versiones_tomcat)
    echo "Versiones disponibles:"
    echo "$versiones"
    read -p "Elija la versión de Tomcat que desea instalar: " version

    echo "Instalando Tomcat $version..."
    apt update && apt install -y openjdk-11-jdk wget

    cd /opt
    wget https://downloads.apache.org/tomcat/tomcat-10/$version/bin/apache-tomcat-${version#v}.tar.gz
    tar -xvzf apache-tomcat-${version#v}.tar.gz
    mv apache-tomcat-${version#v} tomcat
    rm apache-tomcat-${version#v}.tar.gz

    capturar_puerto
    sed -i "s/8080/$puerto/" /opt/tomcat/conf/server.xml
    chmod +x /opt/tomcat/bin/*.sh
    /opt/tomcat/bin/startup.sh

    echo "Tomcat versión $version instalado correctamente en el puerto $puerto."
}
