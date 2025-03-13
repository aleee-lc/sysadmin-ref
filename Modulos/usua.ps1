$FtpRoot = "C:\FTPServer"

function Crear-UsuarioFTP {
    Write-Host "`n=== Crear Usuario FTP ==="

    do {
        $Username = Read-Host "Ingrese el nombre de usuario"
    } until (Validar-NombreUsuario -Username $Username)

    do {
        $Password = Read-Host -AsSecureString "Ingrese la contraseña"
        $PasswordPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        )
    } until (Validar-Contraseña -Password $PasswordPlainText -Username $Username)

    # Seleccionar grupo
    do {
        Write-Host "Seleccione el grupo:"
        Write-Host "1. Reprobados"
        Write-Host "2. Recursadores"
        $GrupoOpcion = Read-Host "Opción (1 o 2)"
        switch ($GrupoOpcion) {
            "1" { $Grupo = "Reprobados"; break }
            "2" { $Grupo = "Recursadores"; break }
            default { Write-Warning "Opción inválida. Intente de nuevo."; continue }
        }
    } until ($Grupo)

    try {
        New-LocalUser -Name $Username -Password $Password
        Add-LocalGroupMember -Group $Grupo -Member $Username
        Write-Host "Usuario '$Username' creado en grupo '$Grupo'." -ForegroundColor Green
    } catch {
        Write-Error "Error al crear el usuario: $_"
        return
    }

    $UserFTPPath = "$FtpRoot\LocalUser\$Username"
    if (!(Test-Path $UserFTPPath)) {
        New-Item -ItemType Directory -Path $UserFTPPath
    }

    icacls $UserFTPPath /grant "${Username}:(OI)(CI)F"
    Write-Host "Usuario FTP '$Username' configurado con acceso a $UserFTPPath." -ForegroundColor Green
}
