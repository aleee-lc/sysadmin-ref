Export-ModuleMember -Function Instalar-ServicioWeb

function Instalar-ServicioWeb {
    Write-Host "=== Instalador de Servicios Web con SSL ===" -ForegroundColor Cyan
    Write-Host "1) Nginx"
    Write-Host "2) IIS"
    Write-Host "3) Lighttpd"
    $servicio = Read-Host "Selecciona el servicio a instalar (1-3)"

    $puerto = Read-Host "Ingresa el puerto a configurar"
    $ssl = Read-Host "¿Deseas habilitar SSL? (s/n)"

    # Verificar si Chocolatey está instalado
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "⚠️ Chocolatey no encontrado. Instalándolo..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }

    function Obtener-Version {
        param([string]$paquete)
        $version = choco info $paquete | Select-String "Latest Package" | ForEach-Object { ($_ -split ': ')[1].Trim() }
        return $version
    }

    function Generar-Certificado {
        $certPath = "C:\ssl"
        if (!(Test-Path $certPath)) { New-Item -ItemType Directory -Path $certPath | Out-Null }

        Write-Host "🔐 Generando certificado SSL..." -ForegroundColor Yellow
        choco install -y openssl.light
        & openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$certPath\ssl.key" -out "$certPath\ssl.crt" -subj "/C=MX/ST=Estado/L=Ciudad/O=MiEmpresa/CN=localhost"
        return $certPath
    }

    switch ($servicio) {
        "1" {
            $version = Obtener-Version "nginx"
            Write-Host "Versión Nginx disponible: $version" -ForegroundColor Cyan
            choco install -y nginx

            $confPath = "C:\tools\nginx\conf\nginx.conf"
            if ($ssl -eq "s") {
                $sslPath = Generar-Certificado
                $confContent = @"
worker_processes  1;
events { worker_connections  1024; }
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    server {
        listen $puerto ssl;
        ssl_certificate $sslPath\ssl.crt;
        ssl_certificate_key $sslPath\ssl.key;
        location / {
            root html;
            index index.html index.htm;
        }
    }
}
"@
            } else {
                $confContent = @"
worker_processes  1;
events { worker_connections  1024; }
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    server {
        listen $puerto;
        location / {
            root html;
            index index.html index.htm;
        }
    }
}
"@
            }
            $confContent | Set-Content $confPath
            Start-Process -FilePath "C:\tools\nginx\nginx.exe"
            Write-Host "✅ Nginx corriendo en el puerto $puerto" -ForegroundColor Green
        }

        "2" {
            Write-Host "⚙️ Instalando y configurando IIS..." -ForegroundColor Green

            # Verifica si IIS ya está instalado
            $iisFeature = Get-WindowsFeature -Name Web-Server
            if (!$iisFeature.Installed) {
                Install-WindowsFeature -Name Web-Server -IncludeManagementTools
                Write-Host "✅ IIS instalado." -ForegroundColor Green
            } else {
                Write-Host "ℹ️ IIS ya está instalado." -ForegroundColor Yellow
            }

            # Crear un sitio en IIS
            Import-Module WebAdministration

            $siteName = "MiSitioWeb"
            $physicalPath = "C:\inetpub\wwwroot"
            if (!(Test-Path $physicalPath)) { New-Item -Path $physicalPath -ItemType Directory | Out-Null }

            # Eliminar el sitio si ya existe
            if (Get-Website -Name $siteName -ErrorAction SilentlyContinue) {
                Remove-Website -Name $siteName
            }

            New-Website -Name $siteName -Port $puerto -PhysicalPath $physicalPath -Force
            Write-Host "✅ IIS configurado con el sitio $siteName en el puerto $puerto" -ForegroundColor Green

            if ($ssl -eq "s") {
                $sslPath = Generar-Certificado
                # En IIS, agregar SSL requiere un binding y un certificado registrado en el almacén de Windows
                Write-Host "⚠️ SSL en IIS requiere importar el certificado manualmente o automatizarlo con CertEnroll." -ForegroundColor Yellow
            }
        }

        "3" {
            $version = Obtener-Version "lighttpd"
            Write-Host "Versión Lighttpd disponible: $version" -ForegroundColor Cyan
            choco install -y lighttpd
            $confPath = "C:\tools\lighttpd\conf\lighttpd.conf"

            Add-Content $confPath "server.document-root = `"C:/tools/lighttpd/htdocs`""
            Add-Content $confPath "server.port = $puerto"

            if ($ssl -eq "s") {
                $sslPath = Generar-Certificado
                Add-Content $confPath "ssl.engine = `"enable`""
                Add-Content $confPath "ssl.pemfile = `"$sslPath\ssl.pem`""
            }
            Start-Process -FilePath "C:\tools\lighttpd\sbin\lighttpd.exe"
            Write-Host "✅ Lighttpd corriendo en el puerto $puerto" -ForegroundColor Green
        }

        Default {
            Write-Host "❌ Opción inválida, saliendo..." -ForegroundColor Red
        }
    }
}
