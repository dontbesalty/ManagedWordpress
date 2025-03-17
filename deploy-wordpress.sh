#!/bin/bash
# deploy-wordpress.sh
# Deploys a new WordPress instance with user isolation

# Exit immediately if a command exits with a non-zero status.
set -e

# Check if jq is installed and install it if it is not
if ! command -v jq &> /dev/null
then
  sudo apt update && sudo apt install -y jq
fi

# Define variables
USERNAME=$1
APPNAME=$2
DOMAIN=$3
DB_PASSWORD=$(openssl rand -base64 12)
echo "$DB_PASSWORD" > "/srv/$USERNAME/apps/$APPNAME/configs/db_password.txt"

# Create appdata directory if it doesn't exist
sudo mkdir -p /var/lib/appdata

# Define appdata file
APPDATA_FILE=/var/lib/appdata/users.json

# Create the appdata file if it doesn't exist
if [ ! -f "$APPDATA_FILE" ]; then
  sudo touch "$APPDATA_FILE"
  sudo chown root:root "$APPDATA_FILE"
  sudo chmod 600 "$APPDATA_FILE"
  echo '{"users": {}}' | sudo tee "$APPDATA_FILE" > /dev/null
fi

# Add user and app data to the appdata file
USER_JSON=$(jq -n \
  --arg username "$USERNAME" \
  --arg appname "$APPNAME" \
  --arg domain "$DOMAIN" \
  --arg dbname "$DB_NAME" \
  --arg public_html "/srv/$USERNAME/apps/$APPNAME/public_html" \
  --arg configs "/srv/$USERNAME/apps/$APPNAME/configs" \
  '{($username): {created: now, apps: {($appname): {domain: $domain, db_name: $dbname, paths: {public_html: $public_html, configs: $configs}}}}}'\
)

# Check if user exists, if not add user, otherwise update user
if jq -e ".\"users\".\"$USERNAME\"" "$APPDATA_FILE" > /dev/null; then
  # Update user
  sudo jq ".\"users\".\"$USERNAME\".apps += $USER_JSON.\"$USERNAME\".apps" "$APPDATA_FILE" > /tmp/tmp.json && sudo mv /tmp/tmp.json "$APPDATA_FILE"
else
  # Add user
  sudo jq ".users += $USER_JSON" "$APPDATA_FILE" > /tmp/tmp.json && sudo mv /tmp/tmp.json "$APPDATA_FILE"
fi

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
sudo mysql -e "CREATE USER IF NOT EXISTS '$USERNAME'@'localhost' IDENTIFIED BY \"$DB_PASSWORD\";"
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
