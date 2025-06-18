#!/bin/bash

# -------------------------- #
# Instalador Dolibarr 21.0.1
# Ubuntu Server 24.04 LTS
# Miguel Blanco Servicios Informaticos
# -------------------------- #

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

echo -e "${BLUE}========= Instalador Interactivo Dolibarr =========${RESET}"

# 🟡 Solicitar datos al usuario
read -sp "🔑 Ingrese la contraseña para el usuario MySQL 'dolibarr': " DOLIPASS
echo
read -p "📧 Ingrese el correo del administrador del servidor (ej: admin@empresa.com): " ADMINMAIL
read -p "🌐 Ingrese la URL o IP del servidor (ej: dolibarr.empresa.com o 192.168.1.100): " SERVERNAME

# 🔄 Actualización del sistema
echo -e "${YELLOW}➡️  Actualizando sistema...${RESET}"
sudo apt update && sudo apt dist-upgrade -y

# 🔧 Repositorio PHP
echo -e "${YELLOW}➡️  Instalando PHP 8.2...${RESET}"
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:ondrej/php
sudo apt update
sudo apt install -y php8.2

# 🕒 Sincronización horaria
echo -e "${YELLOW}➡️  Configurando zona horaria...${RESET}"
sudo apt install -y chrony
sudo timedatectl set-timezone America/Argentina/Buenos_Aires
timedatectl status

# 📦 Instalar dependencias
echo -e "${YELLOW}➡️  Instalando paquetes requeridos...${RESET}"
sudo apt install -y apache2 mariadb-server libapache2-mod-php8.2 \
php8.2-curl php8.2-intl php8.2-mbstring php8.2-xmlrpc php8.2-soap \
php8.2-mysql php8.2-gd php8.2-xml php8.2-cli php8.2-zip php8.2-imap wget unzip git

# ⚙️ Configurar PHP
echo -e "${YELLOW}➡️  Configurando php.ini...${RESET}"
PHPINI="/etc/php/8.2/apache2/php.ini"
sudo sed -i "s/^memory_limit = .*/memory_limit = 512M/" $PHPINI
sudo sed -i "s/^upload_max_filesize = .*/upload_max_filesize = 150M/" $PHPINI
sudo sed -i "s/^post_max_size = .*/post_max_size = 150M/" $PHPINI
sudo sed -i "s/^max_execution_time = .*/max_execution_time = 360/" $PHPINI
sudo sed -i "s|^;date.timezone =.*|date.timezone = America/Argentina/Buenos_Aires|" $PHPINI

# 🛠️ Configurar MariaDB
echo -e "${YELLOW}➡️  Iniciando y asegurando MariaDB...${RESET}"
sudo systemctl enable mariadb
sudo systemctl start mariadb
sudo mysql_secure_installation

echo -e "${YELLOW}➡️  Creando base de datos y usuario...${RESET}"
sudo mysql -u root -p <<EOF
CREATE DATABASE dolibarrdb;
CREATE USER 'dolibarr'@'localhost' IDENTIFIED BY '$DOLIPASS';
GRANT ALL PRIVILEGES ON dolibarrdb.* TO 'dolibarr'@'localhost';
FLUSH PRIVILEGES;
EOF

# 📥 Descargar Dolibarr
echo -e "${YELLOW}➡️  Descargando Dolibarr...${RESET}"
cd /var/www/html
sudo wget -c https://github.com/Dolibarr/dolibarr/archive/refs/tags/21.0.1.tar.gz
sudo tar xzvf 21.0.1.tar.gz
sudo mv dolibarr-21.0.1 dolibarr
sudo rm 21.0.1.tar.gz
sudo chown -R www-data:www-data dolibarr/
sudo chmod -R 755 dolibarr/

# 🌐 Crear VirtualHost
echo -e "${YELLOW}➡️  Configurando VirtualHost...${RESET}"
sudo bash -c "cat > /etc/apache2/sites-available/dolibarr.conf <<EOF
<VirtualHost *:80>
     ServerAdmin $ADMINMAIL
     DocumentRoot /var/www/html/dolibarr/htdocs
     ServerName $SERVERNAME

     <Directory /var/www/html/dolibarr/htdocs/>
          Options +FollowSymlinks
          AllowOverride All
          Require all granted
     </Directory>

     ErrorLog \${APACHE_LOG_DIR}/dolibarr_error.log
     CustomLog \${APACHE_LOG_DIR}/dolibarr_access.log combined
</VirtualHost>
EOF"

# 🚫 Desactivar sitio por defecto
echo -e "${YELLOW}➡️  Desactivando sitio por defecto de Apache...${RESET}"
sudo a2dissite 000-default.conf

# 🔌 Activar Dolibarr y módulos
sudo a2ensite dolibarr.conf
sudo a2enmod rewrite
sudo systemctl enable apache2
sudo systemctl restart apache2

# ✅ Final Miguel Blanco Servicios Informaticos
echo -e "${GREEN}✅ Instalación completada exitosamente.${RESET}"
echo -e "${BLUE}🌐 Acceda desde: http://$SERVERNAME${RESET}"
