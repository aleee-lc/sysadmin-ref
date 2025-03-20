# HTTP  

. "C:\Users\Alejandro\sysadmin-ref\ModulesWin\modulohttp.psm1"

# Verifica si el script se está ejecutando como Administrador
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Este script debe ejecutarse como Administrador." -ForegroundColor Red
    exit
}

while ($true) {
    mostrarMenuHTTP
    $op = Read-Host "Elija el servicio HTTP que desea configurar (1-3):"

    switch ($op) {
        "1" {
            $port = obtenerPuerto "Ingresa el puerto que desea utilizar para el servicio IIS:"
            if ([string]::IsNullOrEmpty($port)){
                continue
            }
            configurarIIS -puerto "$port"
        }
        "2" {
            $version= descargarApache
            $op2 = Read-Host "Selecciona 1 para instalar Apache"
            if ($op2 -eq "1") {
                $port = obtenerPuerto "Ingresa el puerto que desea utilizar para el servicio Apache:"
                if ([string]::IsNullOrEmpty($port)){
                    continue
                }
                configurarApache -puerto $port -version "$version"
            } else {
                Write-Host "Regresando al menú principal." -ForegroundColor Yellow
            }
        }
        "3" {
            $version= descargarNginx
            mostrarMenuHTTP2 "Nginx" $version.stable $version.mainline
            $op2 = Read-Host "Seleccione una opción (1-3):"
            if ($op2 -eq "1"){
                $port = obtenerPuerto "Ingresa el puerto que desea utilizar para el servicio Nginx"
                if ([string]::IsNullOrEmpty($port)){
                    continue
                }
                configurarNginx -puerto $port -version $version.stable
            } elseif ($op2 -eq "2"){
                $port = obtenerPuerto "Ingresa el puerto para Nginx (1024-65535)"
                if ([string]::IsNullOrEmpty($port)){
                    continue
                }
                configurarNginx -puerto $port -version $version.mainline
            } elseif ($op2 -eq "3"){
                Write-Host "Regresando al menú principal." -ForegroundColor Yellow
            } else {
                Write-Host "Opción no válida. Regresando al menú principal." -ForegroundColor Yellow
            }
        }
        "4" {
            exit
        }
        default {
            Write-Host "Opción no válida." -ForegroundColor Red
        }
    }
}
