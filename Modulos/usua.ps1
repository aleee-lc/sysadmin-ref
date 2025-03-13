# Definir ruta raíz para FTP
$FtpRoot = "C:\FTP"

# Función para crear un usuario FTP
function Crear-UsuarioFTP {
    param (
        [string]$NombreUsuario = $(Validar-NombreUsuario),
        [string]$Password = $(Validar-Contraseña -NombreUsuario $NombreUsuario)
    )

    while ($true) {
        $Grupo = switch (Read-Host "Seleccione el grupo: 1 para Reprobados, 2 para Recursadores") {
            "1" { "Reprobados" }
            "2" { "Recursadores" }
            default {
                Write-Host "Opción inválida. Debe seleccionar 1 o 2." -ForegroundColor Red
                continue
            }
        }
        break
    }

    try {
        # Crear el grupo si no existe
        if (-not (Get-LocalGroup -Name $Grupo -ErrorAction SilentlyContinue)) {
            New-LocalGroup -Name $Grupo
        }

        # Crear usuario
        New-LocalUser -Name $NombreUsuario -Password (ConvertTo-SecureString $Password -AsPlainText -Force) -FullName $NombreUsuario -Description "Usuario FTP"

        # Agregar usuario a los grupos
        Add-LocalGroupMember -Group $Grupo -Member $NombreUsuario
        Add-LocalGroupMember -Group "Users" -Member $NombreUsuario

        # Crear carpeta para el usuario
        $UserFTPPath = "$FtpRoot\Usuarios\$NombreUsuario"
        if (!(Test-Path $UserFTPPath)) { 
            New-Item -ItemType Directory -Path $UserFTPPath -Force
        }

        # Aplicar permisos con icacls usando formato seguro
        $Permiso = "$($NombreUsuario):(OI)(CI)F"
        icacls $UserFTPPath /grant $Permiso

        Write-Host "Usuario $NombreUsuario creado en el grupo $Grupo con acceso a $UserFTPPath." -ForegroundColor Green
    } catch {
        Write-Host "Error al crear usuario FTP: $_" -ForegroundColor Red
    }
}

# Función para cambiar el grupo de un usuario FTP
function Cambiar-GrupoUsuarioFTP {
    $NombreUsuario = Read-Host "Ingrese el nombre del usuario"

    if (-not (Get-LocalUser -Name $NombreUsuario -ErrorAction SilentlyContinue)) {
        Write-Host "Error: El usuario no existe." -ForegroundColor Red
        return
    }

    while ($true) {
        $NuevoGrupo = switch (Read-Host "Seleccione el nuevo grupo: 1 para Reprobados, 2 para Recursadores") {
            "1" { "Reprobados" }
            "2" { "Recursadores" }
            default {
                Write-Host "Opción inválida. Debe seleccionar 1 o 2." -ForegroundColor Red
                continue
            }
        }
        break
    }

    try {
        # Eliminar al usuario de los grupos anteriores
        $Grupos = @("Reprobados", "Recursadores")
        foreach ($Grupo in $Grupos) {
            Remove-LocalGroupMember -Group $Grupo -Member $NombreUsuario -ErrorAction SilentlyContinue
        }

        # Agregar al usuario al nuevo grupo
        Add-LocalGroupMember -Group $NuevoGrupo -Member $NombreUsuario

        Write-Host "Usuario $NombreUsuario cambiado al grupo $NuevoGrupo." -ForegroundColor Green
    } catch {
        Write-Host "Error al cambiar grupo del usuario: $_" -ForegroundColor Red
    }
}
