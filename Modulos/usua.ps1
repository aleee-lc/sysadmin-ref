# Crear usuario FTP
$FtpRoot = "C:\FTP"

function Crear-UsuarioFTP {
    $NombreUsuario = Validar-NombreUsuario  
    $Password = Validar-Contraseña -NombreUsuario $NombreUsuario  

    while ($true) {
        $Grupo = switch (Read-Host "Seleccione el grupo: 1 para Reprobados, 2 para Recursadores") {
            "1" { "Reprobados" }
            "2" { "Recursadores" }
            default {
                Write-Host "Opcion invalida. Debe seleccionar 1 o 2." -ForegroundColor Red
                continue
            }
        }
        break
    }

    try {
        if (-not (Get-LocalGroup -Name $Grupo -ErrorAction SilentlyContinue)) {
            New-LocalGroup -Name $Grupo
        }

        New-LocalUser -Name $NombreUsuario -Password (ConvertTo-SecureString $Password -AsPlainText -Force) -FullName $NombreUsuario -Description "Usuario FTP"
        Add-LocalGroupMember -Group $Grupo -Member $NombreUsuario
        Add-LocalGroupMember -Group "Users" -Member $NombreUsuario

        $UserFTPPath = "$FtpRoot\Usuarios\$NombreUsuario"
        if (!(Test-Path $UserFTPPath)) { mkdir $UserFTPPath }
        icacls $UserFTPPath /grant "$NombreUsuario:(OI)(CI)F"

        Write-Host "Usuario $NombreUsuario creado en el grupo $Grupo." -ForegroundColor Green
    } catch {
        Write-Host "Error al crear usuario FTP: $_" -ForegroundColor Red
    }
}

# Cambiar grupo de usuario
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
                Write-Host "Opcion invalida. Debe seleccionar 1 o 2." -ForegroundColor Red
                continue
            }
        }
        break
    }

    try {
        Remove-LocalGroupMember -Group "Reprobados" -Member $NombreUsuario -ErrorAction SilentlyContinue
        Remove-LocalGroupMember -Group "Recursadores" -Member $NombreUsuario -ErrorAction SilentlyContinue
        Add-LocalGroupMember -Group $NuevoGrupo -Member $NombreUsuario

        Write-Host "Usuario $NombreUsuario cambiado al grupo $NuevoGrupo." -ForegroundColor Green
    } catch {
        Write-Host "Error al cambiar grupo del usuario: $_" -ForegroundColor Red
    }
}
