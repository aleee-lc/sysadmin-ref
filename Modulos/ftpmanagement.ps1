# Funcion para instalar IIS y FTP
$FtpRoot = "C:\FTP"

function Instalar-FTP {
    Import-Module ServerManager

    $features = @("Web-Server", "Web-Ftp-Server", "Web-Ftp-Service", "Web-Ftp-Ext")

    try {
        foreach ($feature in $features) {
            $featureStatus = Get-WindowsFeature -Name $feature
            if ($featureStatus.InstallState -ne "Installed") {
                Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction Stop
            }
        }
        Write-Host "IIS y FTP instalados correctamente." -ForegroundColor Green
    } catch {
        Write-Host "Error al instalar IIS y FTP: $_" -ForegroundColor Red
    }
}

# Configurar el servidor FTP
function Configurar-FTP {
    Import-Module WebAdministration

    try {
        if (-not (Test-Path $FtpRoot)) { New-Item -Path $FtpRoot -ItemType Directory -Force }

        if (-not (Get-WebSite -Name "FTPServidor" -ErrorAction SilentlyContinue)) {
            New-WebSite -Name "FTPServidor" -PhysicalPath $FtpRoot -Port 21 -Force
            Set-WebConfigurationProperty -Filter "/system.ftpServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value $true
            Set-WebConfigurationProperty -Filter "/system.ftpServer/security/authentication/basicAuthentication" -Name "enabled" -Value $true
        }

        Restart-WebItem "IIS:\Sites\FTPServidor"
        Write-Host "Servidor FTP configurado correctamente." -ForegroundColor Green
    } catch {
        Write-Host "Error al configurar el servidor FTP: $_" -ForegroundColor Red
    }
}

# Configurar estructura de carpetas FTP
function Configurar-CarpetasFTP {
    $gruposDir = "$FtpRoot\Grupos"
    $publicDir = "$FtpRoot\Publico"

    try {
        New-Item -Path $FtpRoot, $gruposDir, $publicDir -ItemType Directory -Force

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
    } catch {
        Write-Host "Error al configurar carpetas FTP: $_" -ForegroundColor Red
    }
}
