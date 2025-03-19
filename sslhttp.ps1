Import-Module "$PSScriptRoot\ModulesWin\ValidarUser.psm1" -Force -Verbose
Import-Module "$PSScriptRoot\ModulesWin\Instaladorhttp.psm1" -Force -Verbose


Validar-Admin
Instalar-ServicioWeb
