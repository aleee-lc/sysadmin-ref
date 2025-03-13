function Validar-NombreUsuario {
    while ($true) {
        $NombreUsuario = Read-Host "Ingrese el nombre del usuario"
        if ($NombreUsuario.Length -lt 1 -or $NombreUsuario.Length -gt 20 -or $NombreUsuario -match "[^a-zA-Z0-9]" -or $NombreUsuario -match "^\d+$") {
            Write-Host "Error: Nombre de usuario inválido." -ForegroundColor Red
            continue
        }
        if (Get-LocalUser -Name $NombreUsuario -ErrorAction SilentlyContinue) {
            Write-Host "Error: Usuario ya existe." -ForegroundColor Red
            continue
        }
        return $NombreUsuario
    }
}

# Validar contraseña
function Validar-Contraseña {
    param ([string]$NombreUsuario)
    while ($true) {
        $Password = Read-Host "Ingrese contraseña"
        if ($Password.Length -lt 6 -or $Password.Length -gt 14) {
            Write-Host "Error: La contraseña debe tener entre 6 y 14 caracteres." -ForegroundColor Red
            continue
        }
        return $Password
    }
}
