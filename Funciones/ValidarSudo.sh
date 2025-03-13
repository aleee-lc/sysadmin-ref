#Verificar superusuario
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse con privilegios de superusuario"
    exit 1
fi 



