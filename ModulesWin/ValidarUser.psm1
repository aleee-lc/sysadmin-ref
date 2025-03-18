Export-ModuleMember -Function ValidarAdmin

function ValidarAdmin {
    param (
        [string]$OptionalParameter  # Ejemplo de parámetro opcional si quieres usarlo
    )

    # Verificar si se ejecuta como Administrador
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "Este script debe ejecutarse como Administrador." -ForegroundColor Red
        Exit
    }

    Write-Host "El script se está ejecutando como Administrador." -ForegroundColor Green
}


