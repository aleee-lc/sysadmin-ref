Import-Module "C:\Users\Administrator\sysadmin-ref\ModulesWin\FuncionesFTP.psm1"

# Definir la IP fija a usar
$ip_address = "192.168.171.137"

# Llamar a las funciones principales
Configurar-IP -ip_address $ip_address
Configurar-FTP

# Menú Interactivo
while ($true) {
    Write-Host "\n=== Menú de Gestion FTP ===" -ForegroundColor Green
    Write-Host "1. Crear un nuevo usuario FTP"
    Write-Host "2. Cambiar de grupo a un usuario"
    Write-Host "3. Salir"
    
    $opcion = Read-Host "Seleccione una opción (1-3)"
    
    switch ($opcion) {
        "1" { Crear-UsuarioFTP }
        "2" { Cambiar-GrupoFTP }
        "3" {
            Write-Host "Saliendo..." -ForegroundColor Yellow
            exit
        }

        default {
            Write-Host "Opción inválida. Intente de nuevo." -ForegroundColor Red
        }
    }
}
