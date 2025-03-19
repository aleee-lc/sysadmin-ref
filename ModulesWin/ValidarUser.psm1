Export-ModuleMember -Function Validar-Admin

function Validar-Admin {
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "❌ Este script debe ejecutarse como Administrador." -ForegroundColor Red
        Exit
    } else {
        Write-Host "✅ Validación de Administrador correcta" -ForegroundColor Green
    }
}
