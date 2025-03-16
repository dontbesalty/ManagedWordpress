#!/bin/bash
# deploy-wordpress.sh
# Deploys a new WordPress instance with user isolation

# Exit immediately if a command exits with a non-zero status.
set -e

# Define variables
USERNAME=$1
APPNAME=$2
DOMAIN=$3
DB_PASSWORD=$(openssl rand -base64 12)

# Check if required parameters are provided
if [ -z "$USERNAME" ] || [ -z "$APPNAME" ] || [ -z "$DOMAIN" ]; then
  echo "Usage: $0 USERNAME APPNAME DOMAIN"
  exit 1
fi

# Create the user if it doesn't exist
id -u "$USERNAME" &>/dev/null || sudo useradd --system --home "/srv/$USERNAME" "$USERNAME"

# Create the directory structure
mkdir -p "/srv/$USERNAME/apps/$APPNAME/public_html"
mkdir -p "/srv/$USERNAME/apps/$APPNAME/logs"
mkdir -p "/srv/$USERNAME/apps/$APPNAME/ssl"
mkdir -p "/srv/$USERNAME/apps/$APPNAME/configs"

# Set permissions
sudo chown -R "$USERNAME:www-data" "/srv/$USERNAME/apps/$APPNAME/public_html"
sudo chmod -R 750 "/srv/$USERNAME"
sudo chmod 2750 "/srv/$USERNAME/apps/$APPNAME/public_html"

# Create the database and user
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
DB_PREFIX=$(openssl rand -hex 8)
DB_NAME="${DB_PREFIX}_${APPNAME}"
sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"
sudo mysql -e "CREATE USER IF NOT EXISTS '$USERNAME'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
sudo mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$USERNAME'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Download and extract WordPress
cd "/srv/$USERNAME/apps/$APPNAME/public_html"
wp core download --path=. --locale=en_US --version=latest --force
wp core config --dbname="$DB_NAME" --dbuser="$USERNAME" --dbpass="$DB_PASSWORD" --dbhost=localhost --path=. --locale=en_US
wp plugin install redis-object-cache --activate

# Configure Apache
APACHE_CONFIG="\<VirtualHost *:80\>
    ServerName \$DOMAIN
    DocumentRoot /srv/\$USERNAME/apps/\$APPNAME/public_html

    \<Directory /srv/\$USERNAME/apps/\$APPNAME/public_html\>
        AllowOverride All
        Require all granted
    \</Directory\>

    ErrorLog /srv/\$USERNAME/apps/\$APPNAME/logs/apache_error.log
    CustomLog /srv/\$USERNAME/apps/\$APPNAME/logs/apache_access.log combined
\</VirtualHost\>"

echo "$APACHE_CONFIG" > "/srv/$USERNAME/apps/$APPNAME/configs/apache.conf"
sudo a2ensite "/srv/$USERNAME/apps/$APPNAME/configs/apache.conf"

# Configure Nginx
NGINX_CONFIG="server {
    listen 80;
    server_name \$DOMAIN;

    root /srv/\$USERNAME/apps/\$APPNAME/public_html;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}"

echo "$NGINX_CONFIG" > "/srv/$USERNAME/apps/$APPNAME/configs/nginx.conf"
sudo ln -s "/srv/$USERNAME/apps/$APPNAME/configs/nginx.conf" "/etc/nginx/sites-available/$APPNAME.conf"
sudo ln -s "/etc/nginx/sites-available/$APPNAME.conf" "/etc/nginx/sites-enabled/$APPNAME.conf"
sudo nginx -t
sudo systemctl reload nginx

echo "WordPress deployment complete!"
