# instalación de repositorios necesarios (EPEL)
dnf -y install epel-release

# instalación de paquetes web y PHP
dnf -y install nginx php-fpm php-pgsql php-pdo

# instalación e inicialización de postgresql
dnf -y install postgresql-server postgresql
postgresql-setup --initdb

# repositorio oficial de Bareos
dnf -y install wget
URL="https://download.bareos.org/current/EL_9"
wget -O /etc/yum.repos.d/bareos.repo "$URL/bareos.repo"

# instalación de Bareos con backend PostgreSQL y WebUI
dnf -y install bareos bareos-database-postgresql bareos-webui

# activar e iniciar servicios base
systemctl enable --now nginx.service postgresql.service php-fpm.service
 


