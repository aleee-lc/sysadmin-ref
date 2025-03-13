# Importar el modulo de validaciones
. "$PSScriptRoot/Modulos/Validaciones.ps1"
. "$PSScriptRoot/Modulos/usua.ps1"
. "$PSScriptRoot/Modulos/ftpmanagement.ps1"



# Menu interactivo
function Menu-Principal {
    do {
        Write-Host "`n=== Menu Principal ===" -ForegroundColor Cyan
        Write-Host "1. Instalar y Configurar Servidor FTP"
        Write-Host "2. Crear Usuario FTP"
        Write-Host "3. Cambiar Grupo de Usuario"
        Write-Host "4. Salir"

        $opcion = Read-Host "Seleccione una opción (1-4)"
        switch ($opcion) {
            "1" { Instalar-FTP; Configurar-FTP; Configurar-CarpetasFTP }
            "2" { Crear-UsuarioFTP }
            "3" { Cambiar-GrupoUsuarioFTP }
            "4" { break }
            default { Write-Host "Opción inválida." -ForegroundColor Red }
        }
    } while ($true)
}

# Ejecutar menú
Menu-Principal