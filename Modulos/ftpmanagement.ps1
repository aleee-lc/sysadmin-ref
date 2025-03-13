# Script para instalación y configuración del Servidor FTP
$FtpRoot = "C:\FTPServer"

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

        # Habilitar reglas de firewall para FTP
        New-NetFirewallRule -DisplayName "FTP Allow Port 21" -Direction Inbound -Protocol TCP -LocalPort 21 -Action Allow
        New-NetFirewallRule -DisplayName "FTP Passive Ports" -Direction Inbound -Protocol TCP -LocalPort 50000-51000 -Action Allow

        Write-Host "IIS y FTP instalados correctamente." -ForegroundColor Green
    } catch {
        Write-Host "Error al instalar IIS y FTP: $_" -ForegroundColor Red
    }
}

function Configurar-FTP {
    Import-Module WebAdministration

    try {
        if (-not (Test-Path $FtpRoot)) { New-Item -Path $FtpRoot -ItemType Directory -Force }

        if (-not (Get-WebSite -Name "FTPServidor" -ErrorAction SilentlyContinue)) {
            New-WebSite -Name "FTPServidor" -PhysicalPath $FtpRoot -Port 21 -Force
            Set-WebConfigurationProperty -Filter "/system.ftpServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value $true
            Set-WebConfigurationProperty -Filter "/system.ftpServer/security/authentication/basicAuthentication" -Name "enabled" -Value $true
        }

        # Configurar modo pasivo de FTP
        Set-WebConfigurationProperty -Filter "/system.ftpServer/firewallSupport" -Name "lowDataChannelPort" -Value 50000
        Set-WebConfigurationProperty -Filter "/system.ftpServer/firewallSupport" -Name "highDataChannelPort" -Value 51000

        Restart-WebItem "IIS:\Sites\FTPServidor"
        Write-Host "Servidor FTP configurado correctamente." -ForegroundColor Green
    } catch {
        Write-Host "Error al configurar el servidor FTP: $_" -ForegroundColor Red
    }
}
