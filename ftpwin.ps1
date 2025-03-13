# Importar módulos dinámicamente
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "$scriptPath\Modulos\validaciones.ps1"
. "$scriptPath\Modulos\ftpmanagement.ps1"
. "$scriptPath\Modulos\usua.ps1"

function Menu-Principal {
    do {
        Write-Host "`n=== Menú Principal ===" -ForegroundColor DarkGreen
        Write-Host "1. Instalar y Configurar Servidor FTP"
        Write-Host "2. Crear Usuario FTP"
        Write-Host "3. Salir"

        $opcion = Read-Host "Seleccione una opción (1-3)"
        switch ($opcion) {
            "1" { Instalar-FTP; Configurar-FTP }
            "2" { Crear-UsuarioFTP }
            "3" { break }
            default { Write-Host "Opción inválida." -ForegroundColor Red }
        }
    } while ($true)
}

Menu-Principal
