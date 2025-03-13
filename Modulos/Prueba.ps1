# Función para instalar IIS y FTP
function Instalar-FTP {
    Import-Module ServerManager
    $features = @("Web-Server", "Web-Ftp-Server", "Web-Ftp-Service", "Web-Ftp-Ext")
    
    foreach ($feature in $features) {
        $featureStatus = Get-WindowsFeature -Name $feature
        if ($featureStatus.InstallState -ne "Installed") {
            Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction Stop
        }
    }
    Write-Host "IIS y FTP instalados correctamente." -ForegroundColor Green
}

# Configurar el servidor FTP
function Configurar-FTP {
    Import-Module WebAdministration

    if (-not (Test-Path "C:\FTP")) { New-Item -Path "C:\FTP" -ItemType Directory -Force }

    if (-not (Get-WebSite -Name "FTPServidor" -ErrorAction SilentlyContinue)) {
        New-WebSite -Name "FTPServidor" -PhysicalPath "C:\FTP" -Port 21 -Force
        Set-WebConfigurationProperty -Filter "/system.ftpServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value $true
        Set-WebConfigurationProperty -Filter "/system.ftpServer/security/authentication/basicAuthentication" -Name "enabled" -Value $true
    }

    Restart-WebItem "IIS:\Sites\FTPServidor"
    Write-Host "Servidor FTP configurado correctamente." -ForegroundColor Green
}

# Configurar estructura de carpetas FTP
function Configurar-CarpetasFTP {
    $ftpRoot = "C:\FTP"
    $gruposDir = "$ftpRoot\Grupos"
    $publicDir = "$ftpRoot\Publico"

    New-Item -Path $ftpRoot, $gruposDir, $publicDir -ItemType Directory -Force

    $grupos = @("Reprobados", "Recursadores")
    foreach ($grupo in $grupos) {
        if (-not (Get-LocalGroup -Name $grupo -ErrorAction SilentlyContinue)) {
            New-LocalGroup -Name $grupo -Description "Grupo de $grupo"
        }
        New-Item -Path "$gruposDir\$grupo" -ItemType Directory -Force
    }

    icacls $publicDir /grant "IIS_IUSRS:R" /T /C
    icacls $publicDir /grant "Everyone:R" /T /C

    Write-Host "Estructura de directorios y permisos configurados." -ForegroundColor Green
}

# Validar nombre de usuario
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

# Crear usuario FTP
function Crear-UsuarioFTP {
    $NombreUsuario = Validar-NombreUsuario  
    $Password = Validar-Contraseña -NombreUsuario $NombreUsuario  

    while ($true) {
        $Grupo = switch (Read-Host "Seleccione el grupo: 1 para Reprobados, 2 para Recursadores") {
            "1" { "Reprobados" }
            "2" { "Recursadores" }
            default {
                Write-Host "Opción inválida." -ForegroundColor Red
                continue
            }
        }
        break
    }

    if (-not (Get-LocalGroup -Name $Grupo -ErrorAction SilentlyContinue)) {
        New-LocalGroup -Name $Grupo
    }

    New-LocalUser -Name $NombreUsuario -Password (ConvertTo-SecureString $Password -AsPlainText -Force) -FullName $NombreUsuario -Description "Usuario FTP"
    Add-LocalGroupMember -Group $Grupo -Member $NombreUsuario
    Add-LocalGroupMember -Group "Users" -Member $NombreUsuario

    $UserFTPPath = "C:\FTP\Usuarios\$NombreUsuario"
    if (!(Test-Path $UserFTPPath)) { mkdir $UserFTPPath }
    icacls $UserFTPPath /grant "$NombreUsuario:(OI)(CI)F"

    Write-Host "Usuario $NombreUsuario creado en el grupo $Grupo." -ForegroundColor Green
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
                Write-Host "Opción inválida." -ForegroundColor Red
                continue
            }
        }
        break
    }

    Remove-LocalGroupMember -Group "Reprobados" -Member $NombreUsuario -ErrorAction SilentlyContinue
    Remove-LocalGroupMember -Group "Recursadores" -Member $NombreUsuario -ErrorAction SilentlyContinue
    Add-LocalGroupMember -Group $NuevoGrupo -Member $NombreUsuario

    Write-Host "Usuario $NombreUsuario cambiado al grupo $NuevoGrupo." -ForegroundColor Green
}

# Menú interactivo
function Menu-Principal {
    do {
        Write-Host "`n=== Menú Principal ===" -ForegroundColor Cyan
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
