Export-ModuleMember -Function Instalar-ServicioWeb

function Instalar-ServicioWeb {
    Write-Host "=== Instalador de Servicios Web con SSL ===" -ForegroundColor Cyan
    Write-Host "1) Nginx"
    Write-Host "2) IIS"
    Write-Host "3) Lighttpd"

    $servicio = Read-Host "Selecciona el servicio a instalar (1-3)"

    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey no encontrado. Instalando..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }

    switch ($servicio) {
        "1" {
            choco install nginx -y
            Start-Process -FilePath "C:\\tools\\nginx\\nginx.exe"
            Write-Host "✅ NGINX iniciado correctamente" -ForegroundColor Green
        }
        "2" {
            Write-Host "Instalando IIS..." -ForegroundColor Yellow
            Install-WindowsFeature -name Web-Server -IncludeManagementTools
            Write-Host "✅ IIS instalado correctamente" -ForegroundColor Green
        }
        "3" {
            Write-Host "Instalando Lighttpd..." -ForegroundColor Yellow
            choco install lighttpd -y
            Write-Host "✅ Lighttpd instalado correctamente" -ForegroundColor Green
        }
        Default {
            Write-Host "Opción no válida" -ForegroundColor Red
        }
    }
}
