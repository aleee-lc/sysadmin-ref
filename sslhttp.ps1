Import-Module "$PSScriptRoot\ModulesWin\Instaladorhttp.psm1" -Force
Import-Module "$PSScriptRoot\ModulesWin\ValidarUser.psm1" -Force

Validar-Admin
Instalar-ServicioWeb
