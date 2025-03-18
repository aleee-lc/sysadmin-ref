#!/bin/bash

echo "=== Instalador de Servicios con SSL ==="
echo "1) Nginx"
echo "2) Apache2"
echo "3) Lighttpd"
read -p "Selecciona el servicio a instalar (1-3): " servicio

read -p "Ingresa el puerto en el que quieres que escuche: " puerto
read -p "¿Deseas habilitar SSL? (s/n): " ssl

# Función para generar certificado SSL autofirmado
generar_certificado() {
    mkdir -p /etc/ssl/mi_ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/mi_ssl/ssl.key \
    -out /etc/ssl/mi_ssl/ssl.crt \
    -subj "/C=MX/ST=Estado/L=Ciudad/O=MiEmpresa/CN=localhost"
    echo "✅ Certificado SSL generado en /etc/ssl/mi_ssl/"
}

case $servicio in
  1)
    echo "Instalando NGINX..."
    apt update && apt install -y nginx openssl

    if [ "$ssl" == "s" ]; then
        generar_certificado
        cat > /etc/nginx/sites-available/default <<EOF
server {
    listen $puerto ssl;
    ssl_certificate /etc/ssl/mi_ssl/ssl.crt;
    ssl_certificate_key /etc/ssl/mi_ssl/ssl.key;
    root /var/www/html;
    index index.html;
}
EOF
    else
        cat > /etc/nginx/sites-available/default <<EOF
server {
    listen $puerto;
    root /var/www/html;
    index index.html;
}
EOF
    fi

    systemctl restart nginx
    echo "✅ NGINX configurado y ejecutándose en el puerto $puerto"
    ;;
    
  2)
    echo "Instalando Apache2..."
    apt update && apt install -y apache2 openssl

    if [ "$ssl" == "s" ]; then
        generar_certificado
        a2enmod ssl
        cat > /etc/apache2/sites-available/mi_ssl.conf <<EOF
<VirtualHost *:$puerto>
    DocumentRoot /var/www/html
    SSLEngine on
    SSLCertificateFile /etc/ssl/mi_ssl/ssl.crt
    SSLCertificateKeyFile /etc/ssl/mi_ssl/ssl.key
</VirtualHost>
EOF
        a2ensite mi_ssl
        systemctl restart apache2
        echo "✅ Apache configurado con SSL en el puerto $puerto"
    else
        sed -i "s/Listen 80/Listen $puerto/" /etc/apache2/ports.conf
        systemctl restart apache2
        echo "✅ Apache ejecutándose en el puerto $puerto"
    fi
    ;;

  3)
    echo "Instalando Lighttpd..."
    apt update && apt install -y lighttpd openssl

    if [ "$ssl" == "s" ]; then
        generar_certificado
        lighttpd-enable-mod ssl

        cat > /etc/lighttpd/lighttpd.conf <<EOF
server.modules = (
    "mod_access",
    "mod_alias",
    "mod_compress",
    "mod_redirect",
    "mod_openssl"
)

server.document-root        = "/var/www/html"
server.port                 = $puerto
ssl.engine                  = "enable"
ssl.pemfile                 = "/etc/ssl/mi_ssl/ssl.pem"

EOF
        # Crear PEM unificado
        cat /etc/ssl/mi_ssl/ssl.key /etc/ssl/mi_ssl/ssl.crt > /etc/ssl/mi_ssl/ssl.pem
        systemctl restart lighttpd
        echo "✅ Lighttpd configurado con SSL en el puerto $puerto"
    else
        cat > /etc/lighttpd/lighttpd.conf <<EOF
server.modules = (
    "mod_access",
    "mod_alias",
    "mod_compress",
    "mod_redirect"
)

server.document-root        = "/var/www/html"
server.port                 = $puerto
EOF
        systemctl restart lighttpd
        echo "✅ Lighttpd configurado y ejecutándose en el puerto $puerto"
    fi
    ;;
    
  *)
    echo "❌ Opción inválida"
    ;;
esac
