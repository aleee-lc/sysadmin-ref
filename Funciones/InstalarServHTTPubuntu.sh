# Función para instalar dependencias esenciales
instalar_dependencias() {
    local paquetes=(net-tools wget default-jdk)
    local instalar=()

    # Verificar qué paquetes no están instalados
    for pkg in "${paquetes[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            instalar+=("$pkg")
        fi
    done

    # Instalar solo si hay paquetes faltantes
    if [ ${#instalar[@]} -gt 0 ]; then
        echo -e "${AMARILLO}Instalando paquetes necesarios: ${instalar[*]}...${NORMAL}"
        apt update && apt install -y "${instalar[@]}" || {
            echo -e "${ROJO}Error al instalar paquetes. Verifique su conexión a Internet.${NORMAL}"
            exit 1
        }
    else
        echo -e "${VERDE}Todos los paquetes necesarios ya están instalados.${NORMAL}"
    fi
}

# Función para instalar y configurar Apache
instalar_apache() {
    local puerto=$1

    if ! dpkg -l | grep -q "^ii  apache2"; then
        echo -e "${AMARILLO}Instalando Apache2...${NORMAL}"
        apt update && apt install -y apache2
    fi

    sed -i "/^Listen /c\Listen $puerto" /etc/apache2/ports.conf
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

    sed -i "s/port=\"8080\"/port=\"$puerto\"/" "$tomcat_home/conf/server.xml"

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

# Función para instalar Nginx o Lighttpd
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

    case "$servicio" in
        "Nginx")
            sed -i "s/listen 80;/listen $puerto;/" /etc/nginx/sites-available/default
            systemctl restart nginx
            ;;
        "Lighttpd")
            sed -i "s/server.port[[:space:]]=[[:space:]][0-9]*/server.port = $puerto/" /etc/lighttpd/lighttpd.conf
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

# Instalar dependencias esenciales
instalar_dependencias