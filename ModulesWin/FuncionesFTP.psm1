function Configurar-FTP {
    # Instalación del Servidor FTP en Windows Server
    Install-WindowsFeature -Name Web-Ftp-Server, Web-Server -IncludeManagementTools
    Import-Module WebAdministration
    
    # Creación de Carpetas
    mkdir C:\FTP
    mkdir C:\FTP\publica
    mkdir C:\FTP\reprobados
    mkdir C:\FTP\recursadores
    mkdir C:\FTP\LocalUser
    mkdir C:\FTP\LocalUser\Public
    
    # Verificar que las carpetas existen antes de continuar
    if (!(Test-Path "C:\FTP\publica")) { mkdir "C:\FTP\publica" }
    if (!(Test-Path "C:\FTP\reprobados")) { mkdir "C:\FTP\reprobados" }
    if (!(Test-Path "C:\FTP\recursadores")) { mkdir "C:\FTP\recursadores" }
    if (!(Test-Path "C:\FTP\LocalUser")) { mkdir "C:\FTP\LocalUser" }
    if (!(Test-Path "C:\FTP\LocalUser\Public")) { mkdir "C:\FTP\LocalUser\Public" }
    
    # Crear el Sitio FTP en IIS
    New-WebFtpSite -Name "FTPServidor" -Port 21 -PhysicalPath "C:\FTP"
    
    # Configuración de autenticación
    Set-ItemProperty "IIS:\Sites\FTPServidor" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value 1
    Set-ItemProperty "IIS:\Sites\FTPServidor" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value 1
    
    Set-ItemProperty "IIS:\Sites\FTPServidor" -Name ftpServer.userIsolation.mode -Value "IsolateRootDirectoryOnly"
    
    cmd /c mklink /d "C:\FTP\LocalUser\Public\publica" "C:\FTP\publica"
    
    # Crear Grupos de Usuarios si no existen
    if (!(Get-LocalGroup -Name "reprobados" -ErrorAction SilentlyContinue)) {
        net localgroup "reprobados" /add
    }
    if (!(Get-LocalGroup -Name "recursadores" -ErrorAction SilentlyContinue)) {
        net localgroup "recursadores" /add
    }
    if (!(Get-LocalGroup -Name "publica" -ErrorAction SilentlyContinue)) {
        net localgroup "publica" /add
    }
    
    Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users="*";permissions=3} -PSPath IIS:\ -Location "FTPServidor"
    
    # Eliminar configuraciones previas en las carpetas
    Remove-WebConfigurationProperty -PSPath IIS:\ -Location "FTPServidor/publica" -Filter "system.ftpServer/security/authorization" -Name "."
    Remove-WebConfigurationProperty -PSPath IIS:\ -Location "FTPServidor/reprobados" -Filter "system.ftpServer/security/authorization" -Name "."
    Remove-WebConfigurationProperty -PSPath IIS:\ -Location "FTPServidor/recursadores" -Filter "system.ftpServer/security/authorization" -Name "."
    
    # Asignar permisos específicos a cada grupo con `Add-WebConfiguration`
    Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users="*";permissions=1} -PSPath IIS:\ -Location "FTPServidor/publica"
    Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";roles="reprobados";permissions=3} -PSPath IIS:\ -Location "FTPServidor/reprobados"
    Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";roles="recursadores";permissions=3} -PSPath IIS:\ -Location "FTPServidor/recursadores"
    Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";roles="publica";permissions=3} -PSPath IIS:\ -Location "FTPServidor/publica"
    
    
    # Deshabilitar SSL en el FTP
    Set-ItemProperty "IIS:\Sites\FTPServidor" -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
    Set-ItemProperty "IIS:\Sites\FTPServidor" -Name ftpServer.security.ssl.dataChannelPolicy -Value 0
    
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
    
    # Configurar Firewall
    New-NetFirewallRule -DisplayName "FTP (Puerto 21)" -Direction Inbound -Protocol TCP -LocalPort 21 -Action Allow
    New-NetFirewallRule -DisplayName "FTP PASV (50000-51000)" -Direction Inbound -Protocol TCP -LocalPort 50000-51000 -Action Allow
    }
    
    Export-ModuleMember -Function Configurar-FTP



    function Configurar-IP {
        param (
            [string]$ip_address
        )
        $mascara = "255.255.255.0"
        netsh interface ipv4 set address name="Ethernet 2" static $ip_address $mascara
        Write-Host "IP configurada correctamente en $ip_address" -ForegroundColor Green
    }
    


function Crear-UsuarioFTP {
    $NombreUsuario = Validar-NombreUsuario  # Se asegura que sea válido antes de continuar
    $Password = Validar-Contrasena -NombreUsuario $NombreUsuario  # Se asegura que la contraseña sea válida

    while ($true) {
        $opcionGrupo = Read-Host "Seleccione el grupo: 1 para Reprobados, 2 para Recursadores"
        
        if ($opcionGrupo -eq "1") {
            $Grupo = "reprobados"
            break  # Salimos del bucle porque ya es válido
        } elseif ($opcionGrupo -eq "2") {
            $Grupo = "recursadores"
            break  # Salimos del bucle porque ya es válido
        } else {
            Write-Host "Error: Debe seleccionar 1 para Reprobados o 2 para Recursadores." -ForegroundColor Red
            continue  # Repite la selección del grupo
        }
    }

    net user $NombreUsuario $Password /add
    net localgroup $Grupo $NombreUsuario /add
    net localgroup "publica" $NombreUsuario /add

    # Crear carpeta del usuario y vincular carpetas públicas y de grupo
    if (!(Test-Path "C:\FTP\$NombreUsuario")) { mkdir "C:\FTP\$NombreUsuario" }
    if (!(Test-Path "C:\FTP\LocalUser\$NombreUsuario")) { mkdir "C:\FTP\LocalUser\$NombreUsuario" }

    # Vincular carpetas públicas y de grupo
    cmd /c mklink /d "C:\FTP\LocalUser\$NombreUsuario\publica" "C:\FTP\publica"
    cmd /c mklink /d "C:\FTP\LocalUser\$NombreUsuario\$Grupo" "C:\FTP\$Grupo"
    cmd /c mklink /d "C:\FTP\LocalUser\$NombreUsuario\$NombreUsuario" "C:\FTP\$NombreUsuario"

    Remove-WebConfigurationProperty -PSPath IIS:\ -Location "FTPServidor/$NombreUsuario" -Filter "system.ftpServer/security/authorization" -Name "."

    # Asignar permisos al usuario en IIS en su propia carpeta
    Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users="$NombreUsuario";permissions=3} -PSPath IIS:\ -Location "FTPServidor/$NombreUsuario"

    Write-Host "Usuario $NombreUsuario creado en el grupo $Grupo." -ForegroundColor Green
}


# Lista de nombres reservados por Windows
$NombresReservados = @("Administrator", "Guest", "System", "LocalService", "NetworkService", "DefaultAccount")

# Función para validar el nombre de usuario
function Validar-NombreUsuario {
    while ($true) {
        $NombreUsuario = Read-Host "Ingrese el nombre del usuario"

        if ($NombreUsuario.Length -lt 1 -or $NombreUsuario.Length -gt 8) {
            Write-Host "Error: El nombre de usuario debe tener entre 1 y 8 caracteres." -ForegroundColor Red
            continue
        }

        # Validar que no tenga espacios en blanco
        if ($NombreUsuario -match "\s") {
            Write-Host "Error: El nombre de usuario no puede contener espacios en blanco." -ForegroundColor Red
            continue
        }

        if ($NombreUsuario -match "[^a-zA-Z0-9]") {
            Write-Host "Error: El nombre de usuario no puede contener caracteres especiales." -ForegroundColor Red
            continue
        }

        if ($NombreUsuario -match "^\d+$") {
            Write-Host "Error: El nombre de usuario no puede ser solo números, debe incluir al menos una letra." -ForegroundColor Red
            continue
        }

        # Validar que no inicie con un número
        if ($NombreUsuario -match "^\d") {
            Write-Host "Error: El nombre de usuario no puede iniciar con un número." -ForegroundColor Red
            continue
        }

        if ($NombresReservados -contains $NombreUsuario) {
            Write-Host "Error: El nombre de usuario no puede ser un nombre reservado del sistema." -ForegroundColor Red
            continue
        }

        if (Get-LocalUser -Name $NombreUsuario -ErrorAction SilentlyContinue) {
            Write-Host "Error: El nombre de usuario ya existe en el sistema, elija otro." -ForegroundColor Red
            continue
        }

        return $NombreUsuario  # Si es válido, lo retorna
    }
}



function Cambiar-GrupoFTP {
    $NombreUsuario = Read-Host "Ingrese el nombre del usuario"

    if (-not (Get-LocalUser -Name $NombreUsuario -ErrorAction SilentlyContinue)) {
        Write-Host "Usuario no encontrado." -ForegroundColor Red
        return
    }

    $GrupoActual = if ((Get-LocalGroupMember -Group "reprobados" -Member $NombreUsuario -ErrorAction SilentlyContinue)) {
        "reprobados"
    } elseif ((Get-LocalGroupMember -Group "recursadores" -Member $NombreUsuario -ErrorAction SilentlyContinue)) {
        "recursadores"
    } else {
        Write-Host "El usuario no pertenece a ningún grupo." -ForegroundColor Red
        return 
    }

    $NuevoGrupo = if ($GrupoActual -eq "reprobados") { "recursadores" } else { "reprobados" }

    Remove-LocalGroupMember -Group $GrupoActual -Member $NombreUsuario
    net localgroup $NuevoGrupo $NombreUsuario /add

    Remove-Item "C:\FTP\LocalUser\$NombreUsuario\$GrupoActual" -Force
    cmd.exe /c mklink /d "C:\FTP\LocalUser\$NombreUsuario\$NuevoGrupo" "C:\FTP\$NuevoGrupo"

    # Actualizar permisos en IIS
    Remove-WebConfigurationProperty -PSPath IIS:\ -Location "FTPServidor/$NombreUsuario" -Filter "system.ftpServer/security/authorization" -Name "."
    Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users="$NombreUsuario";permissions=3} -PSPath IIS:\ -Location "FTPServidor/$NombreUsuario"

    # Eliminar cualquier configuración previa en IIS
    Remove-WebConfigurationProperty -PSPath IIS:\ -Location "FTPServidor/$NuevoGrupo" -Filter "system.ftpServer/security/authorization" -Name "."
    # Asignar permisos al grupo "recursadores"
    Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";roles="$NuevoGrupo";permissions=3} -PSPath IIS:\ -Location "FTPServidor/$NuevoGrupo"

    Restart-Service FTPSVC

    Write-Host "Usuario $NombreUsuario ahora pertenece a $NuevoGrupo." -ForegroundColor Green
}


function Validar-Contrasena {
    param ([string]$NombreUsuario)

    while ($true) {
        $Password = Read-Host "Ingrese contraseña"

        if ($Password -eq "") {
            Write-Host "Error: La contraseña no puede estar vacía." -ForegroundColor Red
            continue
        }

        if ($Password.Length -lt 3 -or $Password.Length -gt 14) {
            Write-Host "Error: La contraseña debe tener entre 3 y 14 caracteres." -ForegroundColor Red
            continue
        }

        if ($Password -match [regex]::Escape($NombreUsuario)) {
            Write-Host "Error: La contraseña no puede contener el nombre de usuario." -ForegroundColor Red
            continue
        }

        # Verifica los requisitos de la contraseña
        $TieneNumero = $Password -cmatch "\d"  # Requiere al menos un número
        $TieneEspecial = $Password -cmatch "[!@#$%^&*(),.?""{}|<>]"  # Requiere un carácter especial
        $TieneMayuscula = $Password -cmatch "[A-Z]"
        $TieneMinuscula = $Password -cmatch "[a-z]"

        if (-not $TieneNumero -or -not $TieneEspecial -or -not $TieneMayuscula -or -not $TieneMinuscula) {
            Write-Host "Error: La contraseña debe contener al menos: un número, un carácter especial, una letra minuscula y una letra mayuscula." -ForegroundColor Red
            continue
        }

        return $Password 
    }
}

Export-ModuleMember -Function Validar-Contrasena
Export-ModuleMember -Function Crear-UsuarioFTP
Export-ModuleMember -Function Cambiar-GrupoFTP
Export-ModuleMember -Function Validar-NombreUsuario
Export-ModuleMember -Function Configurar-IP

