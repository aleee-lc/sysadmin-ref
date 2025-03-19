# sslhttp.ps1 SIN EMOJIS NI CARACTERES EXTRAÑOS

function Validar-Admin {
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "Este script debe ejecutarse como Administrador." -ForegroundColor Red
        Exit
    } else {
        Write-Host "Validación de Administrador correcta" -ForegroundColor Green
    }
}

function Instalar-Nginx {
    Write-Host "Consultando versiones disponibles de NGINX..."
    $versions = @("1.24.0", "1.23.4", "1.22.1", "1.21.6")

    for ($i = 0; $i -lt $versions.Count; $i++) {
        Write-Host "$($i + 1)) NGINX $($versions[$i])"
    }

    $choice = Read-Host "Selecciona la versión que deseas descargar (1-$($versions.Count))"
    $selectedVersion = $versions[$choice - 1]

    Write-Host "Descargando NGINX versión $selectedVersion..."
    $downloadUrl = "https://nginx.org/download/nginx-$selectedVersion.zip"
    $output = "C:\\Temp\\nginx-$selectedVersion.zip"

    Invoke-WebRequest -Uri $downloadUrl -OutFile $output
    Write-Host "Descarga completada: $output"

    Expand-Archive -Path $output -DestinationPath "C:\\tools\\nginx-$selectedVersion" -Force
    Write-Host "NGINX $selectedVersion instalado en C:\\tools\\nginx-$selectedVersion"

    $puerto = Read-Host "Ingresa el puerto que deseas configurar para NGINX"
    Write-Host "Puerto seleccionado: $puerto"

    $conf = @"
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    server {
        listen       $puerto;
        server_name  localhost;

        location / {
            root   html;
            index  index.html index.htm;
        }
    }
}
"@

    $confPath = "C:\\tools\\nginx-$selectedVersion\\conf\\nginx.conf"
    Set-Content -Path $confPath -Value $conf -Force
    Write-Host "Configuración de NGINX generada con puerto $puerto"

    $nginxExe = "C:\\tools\\nginx-$selectedVersion\\nginx.exe"
    if (Test-Path $nginxExe) {
        Write-Host "Versión de NGINX:"
        & $nginxExe -v
    } else {
        Write-Host "No se encontró nginx.exe para mostrar la versión"
    }
}

function Instalar-ServicioWeb {
    Write-Host "Instalador de Servicios Web"
    Write-Host "1) NGINX (Seleccionar versión y puerto)"
    Write-Host "2) IIS (por defecto de Windows)"
    Write-Host "3) Lighttpd (última versión disponible en choco)"

    $servicio = Read-Host "Selecciona el servicio a instalar (1-3)"

    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey no encontrado. Instalando..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }

    switch ($servicio) {
        "1" { Instalar-Nginx }
        "2" {
            $puerto = Read-Host "Ingresa el puerto que deseas configurar para IIS"
            Write-Host "Instalando IIS..."
            Install-WindowsFeature -name Web-Server -IncludeManagementTools
            Write-Host "IIS instalado correctamente"
            $iisVersion = (Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\InetStp').VersionString
            Write-Host "Versión de IIS: $iisVersion"
            Write-Host "Recuerda configurar el sitio en IIS para escuchar el puerto: $puerto"
        }
        "3" {
            $puerto = Read-Host "Ingresa el puerto que deseas configurar para Lighttpd"
            Write-Host "Instalando Lighttpd..."
            choco install lighttpd -y
            Write-Host "Lighttpd instalado correctamente"
            if (Get-Command lighttpd.exe -ErrorAction SilentlyContinue) {
                Write-Host "Versión de Lighttpd:"
                lighttpd.exe -v
            } else {
                Write-Host "No se pudo obtener la versión de Lighttpd"
            }
            Write-Host "Recuerda configurar manualmente Lighttpd para usar el puerto: $puerto"
        }
        Default {
            Write-Host "Opción no válida"
        }
    }
}

Validar-Admin
Instalar-ServicioWeb
